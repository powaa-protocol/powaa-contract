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
      controller: _fixture.controller,
      rewardDistributor: _fixture.rewardDistributor,
      fakeFeeModel: _fixture.fakeFeeModel,
      fakeMigrator: _fixture.fakeMigrator,
      fakeRewardToken: _fixture.fakeRewardToken,
      fakeStakingToken: _fixture.fakeStakingToken
    });
  }

  function testStake_successfully() external {
    assertEq(
      0,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(0, fixture.fakeStakingToken.totalSupply());

    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);

    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );

    vm.expectEmit(true, true, true, true);
    emit Staked(address(ALICE), STAKE_AMOUNT_1000);

    fixture.tokenVault.stake(STAKE_AMOUNT_1000);

    vm.stopPrank();

    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());
  }

  function testStake_whenStakeAfterMigrated() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.expectEmit(true, true, true, true);
    emit SetMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      uint256(10000)
    );

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      uint256(10000)
    );

    vm.prank(fixture.controller);

    vm.expectEmit(true, true, true, true);
    emit Migrate(uint256(0), uint256(0));

    fixture.tokenVault.migrate();

    vm.startPrank(ALICE);

    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
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

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(address(ALICE), STAKE_AMOUNT_1000);

    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);
    assertEq(
      0,
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

  function testClaimGov_successfully() external {
    vm.warp(1000);

    fixture.fakeStakingToken.mint(address(ALICE), 2000 ether);
    fixture.fakeRewardToken.mint(address(fixture.tokenVault), 100000000 ether);

    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(10000 ether);
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10000 ether);
    fixture.tokenVault.notifyRewardAmount(10000 ether);

    vm.startPrank(ALICE);
    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );
    fixture.tokenVault.stake(STAKE_AMOUNT_1000);
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    vm.warp(5000);

    // 10000 ether / 10000 ether
    assertEq(1, fixture.tokenVault.rewardRate());

    // rewardPerTokenStored.add(
    //   lastTimeRewardApplicable()
    //     .sub(lastUpdateTime)
    //     .mul(rewardRate)
    //     .mul(1e18)
    //     .div(_totalSupply)
    // );

    // ((((5000 - 1000) * 1) * 1e18) / 1000e18)
    assertEq(4, fixture.tokenVault.rewardPerToken());

    vm.expectEmit(true, true, true, true);
    emit RewardPaid(address(ALICE), uint256(4000));

    fixture.tokenVault.claimGov();
    vm.stopPrank();

    // _balances[_account]
    //   .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
    //   .div(1e18)
    //   .add(rewards[_account]);

    // ((1000e18 * (4 - 0)) / 1e18) + 0
    assertEq(4000, fixture.fakeRewardToken.balanceOf(ALICE));
    assertEq(0, fixture.tokenVault.rewards(ALICE));
  }

  function testClaimGov_whenThereAreNoRewardToClaim() external {
    vm.warp(1000);

    fixture.fakeRewardToken.mint(address(fixture.tokenVault), 100000000 ether);

    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(10000 ether);
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10000 ether);
    fixture.tokenVault.notifyRewardAmount(10000 ether);

    vm.startPrank(ALICE);

    vm.warp(5000);

    fixture.tokenVault.claimGov();
    vm.stopPrank();

    assertEq(0, fixture.tokenVault.rewards(ALICE));
  }

  function testExit_successfully() external {
    vm.warp(1000);

    fixture.fakeStakingToken.mint(address(ALICE), 2000 ether);
    fixture.fakeRewardToken.mint(address(fixture.tokenVault), 100000000 ether);

    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(10000 ether);
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10000 ether);
    fixture.tokenVault.notifyRewardAmount(10000 ether);

    vm.startPrank(ALICE);
    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );
    fixture.tokenVault.stake(STAKE_AMOUNT_1000);
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    vm.warp(5000);

    // 10000 ether / 10000 ether
    assertEq(1, fixture.tokenVault.rewardRate());

    // rewardPerTokenStored.add(
    //   lastTimeRewardApplicable()
    //     .sub(lastUpdateTime)
    //     .mul(rewardRate)
    //     .mul(1e18)
    //     .div(_totalSupply)
    // );

    // ((((5000 - 1000) * 1) * 1e18) / 1000e18)
    assertEq(4, fixture.tokenVault.rewardPerToken());

    vm.expectEmit(true, true, true, true);
    emit RewardPaid(address(ALICE), uint256(4000));

    fixture.tokenVault.exit();
    vm.stopPrank();

    // _balances[_account]
    //   .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
    //   .div(1e18)
    //   .add(rewards[_account]);

    // ((1000e18 * (4 - 0)) / 1e18) + 0
    assertEq(4000, fixture.fakeRewardToken.balanceOf(ALICE));
    assertEq(0, fixture.tokenVault.rewards(ALICE));

    assertEq(2000 ether, fixture.fakeStakingToken.balanceOf(ALICE));
  }

  function testMigrate_successfully() external {
    vm.warp(1000);

    fixture.fakeStakingToken.mint(address(ALICE), 2000 ether);
    fixture.fakeStakingToken.mint(address(BOB), 2000 ether);

    fixture.fakeRewardToken.mint(address(fixture.tokenVault), 100000000 ether);

    // setting up
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10000 ether);

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      uint256(10000)
    );

    // users staking period

    vm.startPrank(ALICE);
    fixture.fakeStakingToken.approve(address(fixture.tokenVault), 500 ether);
    fixture.tokenVault.stake(500 ether);
    vm.stopPrank();

    vm.startPrank(BOB);
    fixture.fakeStakingToken.approve(address(fixture.tokenVault), 1500 ether);
    fixture.tokenVault.stake(1500 ether);
    vm.stopPrank();

    assertEq(2000 ether, fixture.tokenVault.totalSupply());

    vm.warp(10000);

    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    vm.startPrank(fixture.controller);
    fixture.tokenVault.migrate();
    vm.stopPrank();

    assertEq(2000 ether, address(fixture.tokenVault).balance);
  }
}