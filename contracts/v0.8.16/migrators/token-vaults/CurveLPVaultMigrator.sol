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
import "../../interfaces/apis/IQuoter.sol";
import "../../interfaces/ILp.sol";
import "../../interfaces/IWETH9.sol";

contract CurveLPVaultMigrator is IMigrator, ReentrancyGuard, Ownable {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant CURVE_STETH_STABLE_SWAP =
    0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
  address public constant CURVE_TRICRYPTO2_STABLE_SWAP =
    0xD51a44d3FaE010294C616388b506AcdA1bfAAE46;

  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  uint256 public govLPTokenVaultFeeRate;
  uint256 public treasuryFeeRate;
  uint256 public controllerFeeRate;

  address public treasury;
  address public govLPTokenVault;
  address public controller;

  IV3SwapRouter public uniswapRouter;
  IQuoter public quoter;

  mapping(address => bool) public tokenVaultOK;
  mapping(address => ICurveFiStableSwap) public tokenVaultPoolRouter;
  mapping(address => uint24) public poolUnderlyingCount;

  struct StableSwapEthMetadata {
    int128 ethIndex;
    bool isUintParam;
  }

  mapping(address => bool) public stableSwapContainEth;
  mapping(address => StableSwapEthMetadata) public stableSwapEthIndex;

  /* ========== EVENTS ========== */
  event Execute(
    uint256 vaultReward,
    uint256 treasuryReward,
    uint256 controllerReward,
    uint256 govLPTokenVaultReward
  );

  /* ========== ERRORS ========== */
  error CurveLPVaultMigrator_OnlyWhitelistedTokenVault();
  error CurveLPVaultMigrator_InvalidFeeRate();

  /* ========== CONSTRUCTOR ========== */
  constructor(
    address _treasury,
    address _controller,
    address _govLPTokenVault,
    uint256 _treasuryFeeRate,
    uint256 _controllerFeeRate,
    uint256 _govLPTokenVaultFeeRate,
    IV3SwapRouter _uniswapRouter,
    IQuoter _quoter
  ) {
    if (govLPTokenVaultFeeRate + treasuryFeeRate >= 1e18) {
      revert CurveLPVaultMigrator_InvalidFeeRate();
    }

    treasury = _treasury;
    controller = _controller;
    govLPTokenVault = _govLPTokenVault;

    govLPTokenVaultFeeRate = _govLPTokenVaultFeeRate;
    controllerFeeRate = _controllerFeeRate;
    treasuryFeeRate = _treasuryFeeRate;

    uniswapRouter = _uniswapRouter;
    quoter = _quoter;

    // stETH Pool contain ETH at index 0
    stableSwapContainEth[CURVE_STETH_STABLE_SWAP] = true;
    stableSwapEthIndex[CURVE_STETH_STABLE_SWAP] = StableSwapEthMetadata({
      ethIndex: 0,
      isUintParam: false
    });

    // TriCrypto2 Pool contain Wrapped ETH at index 2
    stableSwapContainEth[CURVE_TRICRYPTO2_STABLE_SWAP] = true;
    stableSwapEthIndex[CURVE_TRICRYPTO2_STABLE_SWAP] = StableSwapEthMetadata({
      ethIndex: 2,
      isUintParam: true
    });
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
    IERC20(lpToken).safeApprove(address(curveStableSwap), liquidity);

    uint24 underlyingCount = poolUnderlyingCount[address(curveStableSwap)];

    if (stableSwapContainEth[address(curveStableSwap)]) {
      if (stableSwapEthIndex[address(curveStableSwap)].isUintParam) {
        curveStableSwap.remove_liquidity_one_coin(
          liquidity,
          uint256(
            int256(stableSwapEthIndex[address(curveStableSwap)].ethIndex)
          ),
          uint256(0)
        );
      } else {
        curveStableSwap.remove_liquidity_one_coin(
          liquidity,
          stableSwapEthIndex[address(curveStableSwap)].ethIndex,
          uint256(0)
        );
      }
    } else {
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

        // ETH is already counted in this address balance
        // swapping WETH is unnecessary
        if (coinAddress != ETH && coinAddress != WETH9) {
          uint256 swapAmount = IERC20(coinAddress).balanceOf(address(this));
          IERC20(coinAddress).safeApprove(address(uniswapRouter), swapAmount);

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
      }
    }

    _unwrapWETH(address(this));

    uint256 treasuryFee = treasuryFeeRate.mulWadDown(address(this).balance);
    uint256 controllerFee = controllerFeeRate.mulWadDown(address(this).balance);
    uint256 govLPTokenVaultFee = govLPTokenVaultFeeRate.mulWadDown(
      address(this).balance
    );
    uint256 vaultReward = address(this).balance -
      govLPTokenVaultFee -
      treasuryFee -
      controllerFee;

    treasury.safeTransferETH(treasuryFee);
    controller.safeTransferETH(controllerFee);
    govLPTokenVault.safeTransferETH(govLPTokenVaultFee);

    msg.sender.safeTransferETH(vaultReward);

    emit Execute(vaultReward, treasuryFee, controllerFee, govLPTokenVaultFee);
  }

  function _unwrapWETH(address _recipient) private {
    uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));

    if (balanceWETH9 > 0) {
      IWETH9(WETH9).withdraw(balanceWETH9);
      _recipient.safeTransferETH(balanceWETH9);
    }
  }

  function getAmountOut(bytes calldata _data) public returns (uint256) {
    (address lpToken, uint24 poolFee, uint256 stakeAmount) = abi.decode(
      _data,
      (address, uint24, uint256)
    );

    ICurveFiStableSwap curveStableSwap = tokenVaultPoolRouter[msg.sender];
    uint24 underlyingCount = poolUnderlyingCount[address(curveStableSwap)];

    uint256 ratio = stakeAmount.divWadDown(IERC20(lpToken).totalSupply());
    uint256 amountOut = 0;
    uint256 i;
    for (i = 0; i < underlyingCount; i++) {
      address coinAddress = curveStableSwap.coins((i));

      uint256 reserve = curveStableSwap.balances(i);
      uint256 liquidity = uint256(reserve).mulWadDown(ratio);

      if (coinAddress == ETH || coinAddress == WETH9) {
        amountOut += liquidity;
      } else {
        amountOut += quoter.quoteExactInputSingle(
          coinAddress,
          WETH9,
          poolFee,
          liquidity,
          0
        );
      }
    }

    return amountOut;
  }

  function getApproximatedExecutionRewards(bytes calldata _data)
    external
    returns (uint256)
  {
    uint256 totalEth = getAmountOut(_data);
    return controllerFeeRate.mulWadDown(totalEth);
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
