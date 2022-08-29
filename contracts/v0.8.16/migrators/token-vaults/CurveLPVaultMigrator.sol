// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../interfaces/IMigrator.sol";
import "../../interfaces/apis/ICurveFiStableSwap.sol";
import "../../interfaces/apis/IUniswapV2Router02.sol";
import "../../interfaces/ILp.sol";
import "../../interfaces/IWETH9.sol";

contract CurveLPVaultMigrator is IMigrator, ReentrancyGuard, Ownable {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  uint256 public govLPTokenVaultFeeRate;
  uint256 public treasuryFeeRate;

  address public treasury;
  address public govLPTokenVault;

  IV3SwapRouter public uniswapRouter;

  mapping(address => bool) public tokenVaultOK;
  mapping(address => ICurveFiStableSwap) public tokenVaultPoolRouter;
  mapping(address => uint24) public poolUnderlyingCount;

  /* ========== EVENTS ========== */
  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );

  /* ========== ERRORS ========== */
  error CurveLPVaultMigrator_OnlyWhitelistedTokenVault();
  error CurveLPVaultMigrator_InvalidFeeRate();

  /* ========== CONSTRUCTOR ========== */
  constructor(
    address _treasury,
    address _govLPTokenVault,
    uint256 _govLPTokenVaultFeeRate,
    uint256 _treasuryFeeRate,
    IV3SwapRouter _uniswapRouter
  ) {
    if (govLPTokenVaultFeeRate + treasuryFeeRate >= 1e18) {
      revert CurveLPVaultMigrator_InvalidFeeRate();
    }

    treasury = _treasury;
    govLPTokenVault = _govLPTokenVault;
    govLPTokenVaultFeeRate = _govLPTokenVaultFeeRate;
    treasuryFeeRate = _treasuryFeeRate;

    uniswapRouter = _uniswapRouter;
  }

  /* ========== MODIFIERS ========== */

  modifier onlyWhitelistedTokenVault(address caller) {
    if (!tokenVaultOK[caller]) {
      revert CurveLPVaultMigrator_OnlyWhitelistedTokenVault();
    }
    _;
  }

  /* ========== ADMIN FUNCTIONS ========== */
  function whitelistTokenVault(address tokenVault, bool isOk)
    external
    onlyOwner
  {
    tokenVaultOK[tokenVault] = isOk;
  }

  function mapTokenVaultRouter(
    address tokenVault,
    address curveFinancePoolRouter,
    uint24 underlyingCount
  ) external onlyOwner {
    ICurveFiStableSwap router = ICurveFiStableSwap(curveFinancePoolRouter);

    tokenVaultPoolRouter[tokenVault] = router;
    poolUnderlyingCount[address(router)] = underlyingCount;
  }

  /* ========== EXTERNAL FUNCTIONS ========== */
  function execute(bytes calldata _data)
    external
    onlyWhitelistedTokenVault(msg.sender)
    nonReentrant
  {
    (address lpToken, uint24 poolFee) = abi.decode(_data, (address, uint24));
    ICurveFiStableSwap curveStableSwap = tokenVaultPoolRouter[msg.sender];

    uint256 liquidity = IERC20(lpToken).balanceOf(address(this));
    IERC20(lpToken).approve(address(curveStableSwap), liquidity);

    uint24 underlyingCount = poolUnderlyingCount[address(curveStableSwap)];

    if (underlyingCount == 3) {
      curveStableSwap.remove_liquidity(
        liquidity,
        [uint256(0), uint256(0), uint256(0)]
      );
    } else {
      curveStableSwap.remove_liquidity(liquidity, [uint256(0), uint256(0)]);
    }

    uint256 i;
    for (i = 0; i < underlyingCount; i++) {
      address coinAddress = curveStableSwap.coins((i));

      uint256 swapAmount = IERC20(coinAddress).balanceOf(address(this));
      IERC20(coinAddress).approve(address(uniswapRouter), swapAmount);

      IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
        .ExactInputSingleParams({
          tokenIn: coinAddress,
          tokenOut: WETH9,
          fee: poolFee,
          recipient: address(this),
          amountIn: swapAmount,
          amountOutMinimum: 0,
          sqrtPriceLimitX96: 0
        });

      uniswapRouter.exactInputSingle(params);
    }

    _unwrapWETH(address(this));

    uint256 govLPTokenVaultFee = govLPTokenVaultFeeRate.mulWadDown(
      address(this).balance
    );
    uint256 treasuryFee = treasuryFeeRate.mulWadDown(address(this).balance);
    uint256 vaultReward = address(this).balance -
      govLPTokenVaultFee -
      treasuryFee;
    treasury.safeTransferETH(treasuryFee);
    govLPTokenVault.safeTransferETH(govLPTokenVaultFee);

    msg.sender.safeTransferETH(vaultReward);

    emit Execute(vaultReward, govLPTokenVaultFee, treasuryFee);
  }

  function _unwrapWETH(address _recipient) private {
    uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));

    if (balanceWETH9 > 0) {
      IWETH9(WETH9).withdraw(balanceWETH9);
      _recipient.safeTransferETH(balanceWETH9);
    }
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
