// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseTokenVaultFixture.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";

contract TokenVault_Test is BaseTokenVaultFixture {
  using SafeMath for uint256;

  uint256 public constant TOKEN_VAULT_BALANCE = 100000000 ether;
  uint256 public constant MIGRATOR_BALANCE = 100000000 ether;

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

    // we pre-minted our gov token to be distributed later
    fixture.fakeRewardToken.mint(
      address(fixture.tokenVault),
      TOKEN_VAULT_BALANCE
    );

    // we pre-minted plenty of native tokens for the mocked migrator
    // and pretend that it actually does the swapping when we executing migration
    vm.deal(address(fixture.fakeMigrator), MIGRATOR_BALANCE);
  }

  function _simulateStake(address _user, uint256 _amount) internal {
    vm.startPrank(_user);
    fixture.fakeStakingToken.approve(address(fixture.tokenVault), _amount);

    vm.expectEmit(true, true, true, true);
    emit Staked(_user, _amount);

    fixture.tokenVault.stake(_amount);
    vm.stopPrank();
  }

  function _simulateMigrate(
    uint256 _rewardDuration,
    uint256 _rewardAmount,
    uint256 _campaignEndBlock,
    uint24 _feePool,
    uint256 _exchangeToNativeRate
  ) internal {
    // setting up
    fixture.tokenVault.setRewardsDuration(_rewardDuration);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(_rewardAmount);

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      _campaignEndBlock,
      _feePool
    );

    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      _exchangeToNativeRate
    );
    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeRewardToken),
      _exchangeToNativeRate
    );

    vm.prank(fixture.controller);
    fixture.tokenVault.migrate();
  }

  function testSetRewardsDuration_whenCallAtProperTime() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(10000 ether);
    fixture.tokenVault.setRewardsDuration(10000 ether);
  }

  function testSetRewardsDuration_whenCallWithUnauthorizedAccount() external {
    vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));

    vm.prank(ALICE);
    fixture.tokenVault.setRewardsDuration(10000 ether);
  }

  function testSetRewardsDuration_whenCallBeforeRewardPeriod() external {
    fixture.tokenVault.setRewardsDuration(10000 ether);

    // reward period will be set to block timestamp 10000e18
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    vm.warp(1);

    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_RewardPeriodMustBeCompleted()")
    );
    fixture.tokenVault.setRewardsDuration(10000 ether);
  }

  function testNotifyRewardAmount_whenCallBeforeRewardPeriodFinish() external {
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    assertEq(uint256(block.timestamp), fixture.tokenVault.lastUpdateTime());
    assertEq(uint256(block.number), fixture.tokenVault.campaignStartBlock());
    assertEq(
      uint256(block.timestamp).add(10000 ether),
      fixture.tokenVault.periodFinish()
    );
  }

  function testNotifyRewardAmount_whenUsingAmountGreaterThanVaultBalance()
    external
  {
    fixture.tokenVault.setRewardsDuration(1);

    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_ProvidedRewardTooHigh()")
    );
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(TOKEN_VAULT_BALANCE.add(1 ether));
  }

  function testNotifyRewardAmount_whenCallWhileTheRewardPeriodIsNotYetFinish()
    external
  {
    fixture.tokenVault.setRewardsDuration(500);

    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    vm.warp(400);
    vm.roll(100);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    assertEq(400, fixture.tokenVault.lastUpdateTime());
    assertEq(100, fixture.tokenVault.campaignStartBlock());
    assertEq(900, fixture.tokenVault.periodFinish());
  }

  function testStake_whenStakingIsAllowed() external {
    assertEq(
      0,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(0, fixture.tokenVault.totalSupply());

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());
  }

  function testStake_whenStakeAfterMigrated() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.expectEmit(true, true, true, true);
    emit Migrate(uint256(0), uint256(0));

    _simulateMigrate(1, 1, 10000, 0, 1 ether);

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

  function testWithdraw_whenWithdrawalIsAllowed() external {
    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(address(ALICE), STAKE_AMOUNT_1000);

    vm.prank(ALICE);
    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);
    assertEq(
      0,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(0, fixture.tokenVault.totalSupply());
  }

  function testWithdraw_whenWithdrawWithZeroAmount() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotWithdrawZeroAmount()")
    );
    fixture.tokenVault.withdraw(0);

    vm.stopPrank();
  }

  function testWithdraw_whenWithdrawAfterMigrated() external {
    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    _simulateMigrate(1, 1, 10000, 0, 1 ether);

    vm.startPrank(ALICE);

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);

    vm.stopPrank();
  }

  function testClaimGov_whenUserRewardIsAvailableAndUnclaimed() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(10000 ether);
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10000 ether);
    fixture.tokenVault.notifyRewardAmount(10000 ether);

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

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

    vm.prank(ALICE);
    fixture.tokenVault.claimGov();

    // _balances[_account]
    //   .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
    //   .div(1e18)
    //   .add(rewards[_account]);

    // ((1000e18 * (4 - 0)) / 1e18) + 0
    assertEq(4000, fixture.fakeRewardToken.balanceOf(ALICE));
    assertEq(0, fixture.tokenVault.rewards(ALICE));
  }

  function testClaimGov_whenThereAreNoRewardToClaim() external {
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

  function testExit_whenUserStakedAndAvailableRewardUnclaimed() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(10000 ether);
    fixture.tokenVault.setRewardsDuration(10000 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10000 ether);
    fixture.tokenVault.notifyRewardAmount(10000 ether);

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

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

    vm.prank(ALICE);
    fixture.tokenVault.exit();

    // _balances[_account]
    //   .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
    //   .div(1e18)
    //   .add(rewards[_account]);

    // ((1000e18 * (4 - 0)) / 1e18) + 0
    assertEq(4000, fixture.fakeRewardToken.balanceOf(ALICE));
    assertEq(0, fixture.tokenVault.rewards(ALICE));

    assertEq(1000 ether, fixture.fakeStakingToken.balanceOf(ALICE));
  }

  function testMigrate_whenParamsAreProperlySetUp() external {
    // users staking period
    fixture.fakeStakingToken.mint(ALICE, 500 ether);
    _simulateStake(ALICE, 500 ether);
    fixture.fakeStakingToken.mint(BOB, 1500 ether);
    _simulateStake(BOB, 1500 ether);
    assertEq(2000 ether, fixture.tokenVault.totalSupply());

    // vm.warp(10000);

    vm.expectEmit(true, true, true, true);
    emit Migrate(2000 ether, 2000 ether);

    _simulateMigrate(10000 ether, 10000 ether, 10000, 0, 1 ether);

    assertEq(2000 ether, address(fixture.tokenVault).balance);

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));

    vm.prank(fixture.controller);
    fixture.tokenVault.migrate();
  }

  function testMigrate_whenChainIdIsInvalid() external {
    vm.chainId(1);

    vm.prank(fixture.controller);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_InvalidChainId()"));

    fixture.tokenVault.migrate();
  }

  function testMigrate_whenCallerIsNotController() external {
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotController()"));

    fixture.tokenVault.migrate();
  }

  function testClaimETH_whenUsersProperlyStaked() external {
    fixture.fakeStakingToken.mint(ALICE, 500 ether);
    _simulateStake(ALICE, 500 ether);
    fixture.fakeStakingToken.mint(BOB, 1500 ether);
    _simulateStake(BOB, 1500 ether);
    _simulateMigrate(10000 ether, 10000 ether, 10000, 0, 1 ether);

    assertEq(2000 ether, address(fixture.tokenVault).balance);

    vm.prank(BOB);
    fixture.tokenVault.claimETH();
    vm.prank(ALICE);
    fixture.tokenVault.claimETH();

    assertEq(500 ether, ALICE.balance);
    assertEq(1500 ether, BOB.balance);
  }
}
