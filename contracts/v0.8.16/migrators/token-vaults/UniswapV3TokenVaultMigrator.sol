// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";

import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../interfaces/IMigrator.sol";
import "../../interfaces/IWETH9.sol";

contract UniswapV2TokenVaultMigrator is IMigrator, ReentrancyGuard, Ownable {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  uint256 public govLPTokenVaultFeeRate;
  uint256 public treasuryFeeRate;
  uint256 public slippage;

  address public treasury;
  address public govLPTokenVault;
  ISwapRouter public router;

  mapping(address => bool) public tokenVaultOK;

  /* ========== EVENTS ========== */
  event RewardAdded(uint256 reward);
  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );
  event SetSlippage(uint256 slippage);
  event WhitelistTokenVault(address tokenVault, bool whitelisted);

  /* ========== ERRORS ========== */
  error UniswapV2VaultMigrator_OnlyWhitelistedTokenVault();
  error UniswapV2VaultMigrator_InvalidFeeRate();

  /* ========== CONSTRUCTOR ========== */
  constructor(
    address _treasury,
    address _govLPTokenVault,
    uint256 _govLPTokenVaultFeeRate,
    uint256 _treasuryFeeRate,
    uint256 _slippage,
    ISwapRouter _router
  ) {
    if (govLPTokenVaultFeeRate + treasuryFeeRate >= 1e18) {
      revert UniswapV2VaultMigrator_InvalidFeeRate();
    }

    treasury = _treasury;
    govLPTokenVault = _govLPTokenVault;
    govLPTokenVaultFeeRate = _govLPTokenVaultFeeRate;
    treasuryFeeRate = _treasuryFeeRate;
    router = _router;
    slippage = _slippage;
  }

  /* ========== MODIFIERS ========== */

  modifier onlyWhitelistedTokenVault(address caller) {
    if (!tokenVaultOK[caller]) {
      revert UniswapV2VaultMigrator_OnlyWhitelistedTokenVault();
    }
    _;
  }

  /* ========== ADMIN FUNCTIONS ========== */
  function whitelistTokenVault(address tokenVault, bool isOk)
    external
    onlyOwner
  {
    tokenVaultOK[tokenVault] = isOk;

    emit WhitelistTokenVault(tokenVault, isOk);
  }

  function setSlippage(uint256 _slippage) external onlyOwner {
    slippage = _slippage;

    emit SetSlippage(_slippage);
  }

  /* ========== EXTERNAL FUNCTIONS ========== */
  function _unwrapWETH(address _recipient) private {
    uint256 balanceWETH9 = IWETH9(WETH9).balanceOf(address(this));

    if (balanceWETH9 > 0) {
      IWETH9(WETH9).withdraw(balanceWETH9);
      _recipient.safeTransferETH(balanceWETH9);
    }
  }

  function execute(bytes calldata _data)
    external
    onlyWhitelistedTokenVault(msg.sender)
    nonReentrant
  {
    (address token, uint24 poolFee) = abi.decode(_data, (address, uint24));

    address[] memory _path = new address[](2);
    _path[0] = token;
    _path[1] = WETH9;
    uint256 swapAmount = IERC20(token).balanceOf(address(this));

    IERC20(token).approve(address(router), swapAmount);

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
      .ExactInputSingleParams({
        tokenIn: token,
        tokenOut: WETH9,
        fee: poolFee,
        recipient: address(this),
        deadline: block.timestamp,
        amountIn: swapAmount,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
      });

    router.exactInputSingle(params);
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

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
