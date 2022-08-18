// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./LinearFeeModelBase.t.sol";

contract LinearFeeModel_TestGetFeeRate is LinearFeeModelBaseTest {
  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenGetFeeRate_withStartBlockAtZero() external {
    uint256 feeRate = linearFeeModel.getFeeRate(0, 1, 2);

    // utilizationRate = 0%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( 100 * 0% ) = 0
    assertEq(feeRate, linearFeeModel.baseRate());
  }

  function test_WhenGetFeeRate_withStartBlockAtZero_withBaseRate50() external {
    linearFeeModel = _setupLinearFeeModel(50, 100);
    uint256 feeRate = linearFeeModel.getFeeRate(0, 1, 2);

    // utilizationRate = 0%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 50 + ( 100 * 0% ) = 50
    assertEq(feeRate, linearFeeModel.baseRate());
  }

  function test_WhenGetFeeRate_withStartBlockAt1() external {
    uint256 feeRate = linearFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( 100 * 25% ) = 25
    assertEq(feeRate, 25);
  }

  function test_WhenGetFeeRate_withStartBlockAt1_withBaseRate50() external {
    linearFeeModel = _setupLinearFeeModel(50, 100);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 50 + ( 100 * 25% ) = 75
    assertEq(feeRate, 75);
  }

  function test_WhenGetFeeRate_withStartBlockAt1_withMultiplierRate75()
    external
  {
    linearFeeModel = _setupLinearFeeModel(0, 75);
    uint256 feeRate = linearFeeModel.getFeeRate(1, 2, 5);

    // utilizationRate = 25%
    // feeRate = baseRate + ( multiplierRate * utilizationRate)
    //         = 0 + ( 75 * 25% ) = 18
    assertEq(feeRate, 18);
  }
}
