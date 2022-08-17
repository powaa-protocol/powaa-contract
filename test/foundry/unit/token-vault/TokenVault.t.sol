// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./BaseTokenVaultFixture.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";

contract TokenVault_Test is BaseTokenVaultFixture {
  TokenVaultTestState public fixture;

  /// @dev foundry's setUp method
  function setUp() public {
    TokenVaultTestState memory _fixture = _scaffoldTokenVaultTestState();

    fixture = TokenVaultTestState({
      tokenVault: _fixture.tokenVault,
      rewardDistributor: _fixture.rewardDistributor,
      fakeRewardToken: _fixture.fakeRewardToken,
      fakeStakingToken: _fixture.fakeStakingToken
    });
  }

  function testStake_successfully() external {
    assertEq(
      ZERO,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(0, fixture.fakeStakingToken.totalSupply());

    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);

    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );
    fixture.tokenVault.stake(STAKE_AMOUNT_1000);

    vm.stopPrank();

    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());
  }

  function testStake_whenStakeAfterMigrationFinished() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);

    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );

    vm.warp(block.timestamp + 100000);
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotStakeAfterMigration()")
    );
    fixture.tokenVault.stake(STAKE_AMOUNT_1000);

    vm.stopPrank();
  }

  function testStake_whenStakeWithZeroAmount() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotStakeZeroAmount()")
    );
    fixture.tokenVault.stake(0);

    vm.stopPrank();
  }

  function testWithdraw_successfully() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);
    vm.startPrank(ALICE);

    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );
    fixture.tokenVault.stake(STAKE_AMOUNT_1000);
    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);
    assertEq(
      ZERO,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(0, fixture.tokenVault.totalSupply());
    vm.stopPrank();
  }

  function testWithdraw_whenStakeWithZeroAmount() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotWithdrawZeroAmount()")
    );
    fixture.tokenVault.withdraw(0);

    vm.stopPrank();
  }
}
