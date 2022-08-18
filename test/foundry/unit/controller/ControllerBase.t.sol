// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../_base/BaseTest.sol";
import "mock-contract/MockContract.sol";
import "../../../../contracts/v0.8.16/Controller.sol";

/// @title An abstraction of the Controller Testing contract, containing a scaffolding method for creating the fixture
abstract contract ControllerBaseTest is BaseTest {
  MockContract internal mockTokenVault;
  Controller internal controller;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    mockTokenVault = new MockContract();
    controller = _setupController();
  }

  function _setupController() internal returns (Controller) {
    Controller _controller = new Controller();

    return _controller;
  }
}
