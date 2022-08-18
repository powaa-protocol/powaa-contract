// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ControllerBase.t.sol";

contract Controller_TestMigration is ControllerBaseTest {
  // Controller event
  event Migrate(address[] vaults);
  event SetVault(address vault);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenMigrationVault() external {
    address[] memory mockTokenVaults = new address[](1);
    mockTokenVaults[0] = address(mockTokenVault);
    vm.expectEmit(true, true, true, true);
    emit SetVault(address(mockTokenVault));
    controller.whitelistVault(address(mockTokenVault));

    emit Migrate(mockTokenVaults);
    controller.migrate();
  }

  function test_WhenMigrationVault_withNoVaults() external {
    vm.expectRevert(abi.encodeWithSignature("Controller_NoVaults()"));
    controller.migrate();
  }

  function test_WhenMigrationVault_withTheCallerIsNotOwner() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
    controller.migrate();
    vm.stopPrank();
  }

  function test_WhenWhitelistVault() external {
    MockContract mockTokenVault2 = new MockContract();
    vm.expectEmit(true, true, true, true);
    emit SetVault(address(mockTokenVault2));
    controller.whitelistVault(address(mockTokenVault2));
  }
}
