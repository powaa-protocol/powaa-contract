// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./UniswapV2GovLPVaultMigratorBase.t.sol";

contract UniswapV2GovLPVaultMigrator_TestExecute is
  UniswapV2GovLPVaultMigratorBaseTest
{
  // UniswapV2GovLPVaultMigrator event
  event SetVault(address vault);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenCallerIsNotWhitelistedContract() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "UniswapV2VaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );
    uniswapV2GovLPVaultMigrator.execute(abi.encode(address(mockLp)));
  }

  function test_WhenExecute_withWhitelistTokenVault() external {
    uniswapV2GovLPVaultMigrator.whitelistTokenVault(address(this), true);

    uniswapV2GovLPVaultMigrator.execute(abi.encode(address(mockLp)));
  }
}
