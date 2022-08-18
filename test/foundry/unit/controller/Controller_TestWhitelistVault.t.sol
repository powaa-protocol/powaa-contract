// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ControllerBase.t.sol";

contract Controller_TestWhitelistVault is ControllerBaseTest {
  // Controller event
  event SetVault(address vault);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenWhitelistVault() external {
    MockContract mockTokenVault2 = new MockContract();
    vm.expectEmit(true, true, true, true);
    emit SetVault(address(mockTokenVault2));
    controller.whitelistVault(address(mockTokenVault2));
  }
}
