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

  ICurveFiStableSwap public curveStableSwap;
  IV3SwapRouter public uniswapRouter;

  mapping(address => bool) public tokenVaultOK;

  /* ========== EVENTS ========== */
  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );

  /* ========== ERRORS ========== */
  error SushiSwapLPVaultMigrator_OnlyWhitelistedTokenVault();
  error SushiSwapLPVaultMigrator_InvalidFeeRate();

  /* ========== CONSTRUCTOR ========== */
  constructor(
    address _treasury,
    address _govLPTokenVault,
    uint256 _govLPTokenVaultFeeRate,
    uint256 _treasuryFeeRate,
    ICurveFiStableSwap _curveStableSwap,
    IV3SwapRouter _uniswapRouter
  ) {
    if (govLPTokenVaultFeeRate + treasuryFeeRate >= 1e18) {
      revert SushiSwapLPVaultMigrator_InvalidFeeRate();
    }

    treasury = _treasury;
    govLPTokenVault = _govLPTokenVault;
    govLPTokenVaultFeeRate = _govLPTokenVaultFeeRate;
    treasuryFeeRate = _treasuryFeeRate;

    curveStableSwap = _curveStableSwap;
    uniswapRouter = _uniswapRouter;
  }

  /* ========== MODIFIERS ========== */

  modifier onlyWhitelistedTokenVault(address caller) {
    if (!tokenVaultOK[caller]) {
      revert SushiSwapLPVaultMigrator_OnlyWhitelistedTokenVault();
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

  /* ========== EXTERNAL FUNCTIONS ========== */
  function execute(bytes calldata _data)
    external
    onlyWhitelistedTokenVault(msg.sender)
    nonReentrant
  {
    (address lpToken, uint24 poolFee) = abi.decode(_data, (address, uint24));
    address[] memory coins = curveStableSwap.underlying_coins();

    uint256 liquidity = IERC20(lpToken).balanceOf(address(this));
    IERC20(lpToken).approve(address(curveStableSwap), liquidity);
    curveStableSwap.remove_liquidity(liquidity, new uint256[](coins.length));

    uint24 i;
    for (i = 0; i < coins.length; i++) {
      uint256 swapAmount = IERC20(coins[i]).balanceOf(address(this));
      IERC20(coins[i]).approve(address(uniswapRouter), swapAmount);

      IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
        .ExactInputSingleParams({
          tokenIn: coins[i],
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
