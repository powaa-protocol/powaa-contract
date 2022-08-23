// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./UniswapV2GovLPVaultMigratorBase.t.sol";

contract UniswapV2GovLPVaultMigrator_TestExecute is
  UniswapV2GovLPVaultMigratorBaseTest
{
  // UniswapV2GovLPVaultMigrator event
  event Execute(uint256 vaultReward);

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
    uint256 balanceBefore = address(this).balance;
    assertEq(address(mockRouter).balance, 1e18);

    uniswapV2GovLPVaultMigrator.whitelistTokenVault(address(this), true);

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Execute(1e18);
    uniswapV2GovLPVaultMigrator.execute(abi.encode(address(mockLp)));

    uint256 balanceAfter = address(this).balance;

    assertEq(address(mockRouter).balance, 0);
    assertEq(balanceAfter - balanceBefore, 1e18);
  }

  function test_WhenExecute_withWhitelistTokenVaultAndLeftoverTokens()
    external
  {
    vm.deal(address(mockRouter), 1e18 * 2);

    uint256 balanceBefore = address(this).balance;
    assertEq(address(mockRouter).balance, 1e18 * 2);

    uniswapV2GovLPVaultMigrator.whitelistTokenVault(address(this), true);

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Execute(1e18);
    uniswapV2GovLPVaultMigrator.execute(abi.encode(address(mockLp)));

    uint256 balanceAfter = address(this).balance;

    assertEq(address(mockRouter).balance, 1e18);
    assertEq(balanceAfter - balanceBefore, 1e18);
  }
}