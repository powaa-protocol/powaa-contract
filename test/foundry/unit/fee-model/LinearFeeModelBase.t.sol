// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../_base/BaseTest.sol";

import "../../../../contracts/v0.8.16/fee-model/LinearFeeModel.sol";

/// @title An abstraction of the LinearFeeModel Testing contract, containing a scaffolding method for creating the fixture
abstract contract LinearFeeModelBaseTest is BaseTest {
  LinearFeeModel internal linearFeeModel;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    linearFeeModel = _setupLinearFeeModel(0, 100);
  }

  function _setupLinearFeeModel(uint256 baseRate, uint256 multiplierRate)
    internal
    returns (LinearFeeModel)
  {
    LinearFeeModel _linearFeeModel = new LinearFeeModel(
      baseRate,
      multiplierRate
    );

    return _linearFeeModel;
  }
}
