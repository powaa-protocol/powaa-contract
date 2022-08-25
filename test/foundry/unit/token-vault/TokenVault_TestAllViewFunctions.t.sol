// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./TokenVaultBaseTest.t.sol";
import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockETHLpToken.sol";
import "../_mock/MockUniswapV2Router01.sol";
import "mock-contract/MockContract.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";
import "../../../../contracts/v0.8.16/migrators/gov-lp-vaults/UniswapV2GovLPVaultMigrator.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";

contract TokenVault_TestViewFunctions is TokenVaultBaseTest {
  function setUp() public override {
    super.setUp();

    fakeRewardToken.mint(address(tokenVault), 1 ether);

    tokenVault.setRewardsDuration(1 days);
    vm.prank(rewardDistributor);
    tokenVault.notifyRewardAmount(1 ether);
  }

  function test_lastTimeRewardApplicable_WhenCallBeforePeriodFinish() external {
    vm.warp(0.5 days);
    assertEq(0.5 days, tokenVault.lastTimeRewardApplicable());
  }

  function test_lastTimeRewardApplicable_WhenCallAfterPeriodFinish() external {
    vm.warp(5 days);
    assertEq(1 days + 1, tokenVault.lastTimeRewardApplicable());
  }
}
