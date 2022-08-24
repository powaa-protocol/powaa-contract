// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

import "../../../_base/BaseTest.sol";
import "../../../_mock/MockTokenVault.sol";
import "../../../_mock/MockUniswapV2Router01.sol";
import "../../../_mock/MockV3SwapRouter.sol";
import "../../../_mock/MockETHLpToken.sol";
import "../../../../../../contracts/v0.8.16/migrators/token-vaults/SushiSwapLPVaultMigrator.sol";
import "../../../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";

/// @title An abstraction of the SushiSwapLPVaultMigrator Testing contract, containing a scaffolding method for creating the fixture
abstract contract SushiSwapLPVaultMigratorBaseTest is BaseTest {
  SushiSwapLPVaultMigrator internal migrator;

  MockUniswapV2Router01 internal v2Router;
  MockV3SwapRouter internal v3Router;

  address internal constant treasury = address(12345);
  address internal constant govLPTokenVault = address(54321);

  event Execute(uint256 vaultReward);

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    migrator = _setupMigrator(0.1 ether, 0.1 ether);
  }

  function _setupMigrator(
    uint256 _govLPTokenVaultFeeRate,
    uint256 _treasuryFeeRate
  ) internal returns (SushiSwapLPVaultMigrator) {
    SushiSwapLPVaultMigrator _migrator = new SushiSwapLPVaultMigrator(
      treasury,
      govLPTokenVault,
      _govLPTokenVaultFeeRate,
      _treasuryFeeRate,
      IUniswapV2Router02(address(v2Router)),
      IV3SwapRouter(address(v3Router))
    );

    return _migrator;
  }
}
