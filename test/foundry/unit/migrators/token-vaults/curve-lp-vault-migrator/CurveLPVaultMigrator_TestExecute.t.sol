// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./CurveLPVaultMigratorBase.t.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../../_mock/MockERC20.sol";
import "../../../_mock/MockWETH9.sol";

contract CurveLPVaultMigrator_TestExecute is CurveLPVaultMigratorBaseTest {
  using SafeMath for uint256;
  using FixedPointMathLib for uint256;

  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );
  // more than enough amount
  uint256 public constant INITIAL_AMOUNT = 100000000000000 ether;

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenCallerIsNotWhitelistedContract() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "CurveLPVaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );
    migrator.execute(abi.encode(address(mockLpToken), uint24(0)));
  }
}
