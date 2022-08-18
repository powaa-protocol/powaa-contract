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
import "../../interfaces/ILp.sol";

contract UniswapV2GovLPVaultMigrator is IMigrator, ReentrancyGuard, Ownable {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  IUniswapV2Router02 public router;

  mapping(address => bool) public tokenVaultOK;

  /* ========== EVENTS ========== */
  event RewardAdded(uint256 reward);
  event Execute(uint256 vaultReward);

  /* ========== ERRORS ========== */
  error UniswapV2VaultMigrator_OnlyWhitelistedTokenVault();
  error UniswapV2VaultMigrator_InvalidFeeRate();

  /* ========== CONSTRUCTOR ========== */
  constructor(IUniswapV2Router02 _router) {
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
  function execute(bytes calldata _data)
    external
    onlyWhitelistedTokenVault(msg.sender)
    nonReentrant
  {
    address lpToken = abi.decode(_data, (address));
    address baseToken = address(ILp(lpToken).token0()) != address(WETH9)
      ? address(ILp(lpToken).token0())
      : address(ILp(lpToken).token1());

    uint256 liquidity = IERC20(lpToken).balanceOf(address(this));
    IERC20(lpToken).approve(address(router), liquidity);
    router.removeLiquidityETH(
      baseToken,
      liquidity,
      0,
      0,
      address(this),
      block.timestamp
    );

    address[] memory _path = new address[](2);
    _path[0] = baseToken;
    _path[1] = WETH9;
    uint256 swapAmount = IERC20(baseToken).balanceOf(address(this));

    IERC20(baseToken).approve(address(router), swapAmount);
    router.swapExactTokensForETH(
      swapAmount,
      0,
      _path,
      address(this),
      block.timestamp
    );

    uint256 vaultReward = address(this).balance;
    msg.sender.safeTransferETH(vaultReward);

    emit Execute(vaultReward);
  }
}
