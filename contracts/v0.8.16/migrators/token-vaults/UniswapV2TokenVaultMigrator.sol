// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../interfaces/IMigrator.sol";
import "../../interfaces/apis/IUniswapV2Router02.sol";

contract UniswapV2TokenVaultMigrator is IMigrator, ReentrancyGuard, Ownable {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  uint256 public govLPTokenVaultFeeRate;
  uint256 public treasuryFeeRate;

  address public treasury;
  address public govLPTokenVault;
  IUniswapV2Router02 public router;

  mapping(address => bool) public tokenVaultOK;

  /* ========== EVENTS ========== */
  event RewardAdded(uint256 reward);
  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );

  /* ========== ERRORS ========== */
  error UniswapV2VaultMigrator_OnlyWhitelistedTokenVault();
  error UniswapV2VaultMigrator_InvalidFeeRate();

  /* ========== CONSTRUCTOR ========== */
  constructor(
    address _treasury,
    address _govLPTokenVault,
    uint256 _govLPTokenVaultFeeRate,
    uint256 _treasuryFeeRate,
    IUniswapV2Router02 _router
  ) {
    if (govLPTokenVaultFeeRate + treasuryFeeRate >= 1e18) {
      revert UniswapV2VaultMigrator_InvalidFeeRate();
    }

    treasury = _treasury;
    govLPTokenVault = _govLPTokenVault;
    govLPTokenVaultFeeRate = _govLPTokenVaultFeeRate;
    treasuryFeeRate = _treasuryFeeRate;
    router = _router;
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
  }

  /* ========== EXTERNAL FUNCTIONS ========== */
  function execute(address token)
    external
    onlyWhitelistedTokenVault(msg.sender)
    nonReentrant
  {
    address[] memory _path = new address[](2);
    _path[0] = token;
    _path[1] = WETH;
    uint256 swapAmount = IERC20(token).balanceOf(address(this));
    uint256 govLPTokenVaultFee = govLPTokenVaultFeeRate.mulWadDown(
      address(this).balance
    );
    uint256 treasuryFee = treasuryFeeRate.mulWadDown(address(this).balance);

    IERC20(token).approve(address(router), swapAmount);
    router.swapExactTokensForETH(
      swapAmount,
      0,
      _path,
      address(this),
      block.timestamp
    );

    uint256 vaultReward = address(this).balance;

    treasury.safeTransferETH(treasuryFee);
    govLPTokenVault.safeTransferETH(govLPTokenVaultFee);
    msg.sender.safeTransferETH(vaultReward);

    emit Execute(vaultReward, govLPTokenVaultFee, treasuryFee);
  }
}
