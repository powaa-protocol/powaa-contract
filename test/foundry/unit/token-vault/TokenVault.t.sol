// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseTokenVaultFixture.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";

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
      treasury: _fixture.treasury,
      rewardDistributor: _fixture.rewardDistributor,
      fakeFeeModel: _fixture.fakeFeeModel,
      fakeMigrator: _fixture.fakeMigrator,
      fakeReserveMigrator: _fixture.fakeReserveMigrator,
      fakeRewardToken: _fixture.fakeRewardToken,
      fakeStakingToken: _fixture.fakeStakingToken,
      fakeGovLpToken: _fixture.fakeGovLpToken
    });

    // we pre-minted our gov token to be distributed later
    fixture.fakeRewardToken.mint(
      address(fixture.tokenVault),
      TOKEN_VAULT_BALANCE
    );

    // we pre-minted plenty of native tokens for the mocked migrator
    // and pretend that it actually does the swapping when we executing migration
    vm.deal(address(fixture.fakeMigrator), MIGRATOR_BALANCE);
    vm.deal(address(fixture.fakeReserveMigrator), MIGRATOR_BALANCE);
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
    uint256 _exchangeToNativeRate,
    uint256 _treasuryFeeRate
  ) internal {
    // setting up
    fixture.tokenVault.setRewardsDuration(_rewardDuration);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(_rewardAmount);

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      IMigrator(address(fixture.fakeReserveMigrator)),
      _campaignEndBlock,
      address(fixture.fakeFeeModel),
      _feePool,
      fixture.treasury,
      _treasuryFeeRate
    );

    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      _exchangeToNativeRate
    );

    vm.prank(fixture.controller);
    fixture.tokenVault.migrate();
  }

  function testSetRewardsDuration_WhenCallAtProperTime() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(100000000);
    fixture.tokenVault.setRewardsDuration(100000000);
  }

  function testSetRewardsDuration_WhenCallWithUnauthorizedAccount() external {
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));

    vm.prank(ALICE);
    fixture.tokenVault.setRewardsDuration(100000000);
  }

  function testSetRewardsDuration_WhenCallDuringRewardPeriod() external {
    // reward period will be 100000000 block long
    fixture.tokenVault.setRewardsDuration(100000000);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    vm.warp(1);

    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_RewardPeriodMustBeCompleted()")
    );
    fixture.tokenVault.setRewardsDuration(100000000);
  }

  function testNotifyRewardAmount_WhenCallBeforeRewardPeriodStart() external {
    fixture.tokenVault.setRewardsDuration(1 ether);

    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    // 10e18 / 1e18
    assertEq(10, fixture.tokenVault.rewardRate());
    assertEq(uint256(block.timestamp), fixture.tokenVault.lastUpdateTime());
    assertEq(uint256(block.number), fixture.tokenVault.campaignStartBlock());
    assertEq(
      uint256(block.timestamp).add(1 ether),
      fixture.tokenVault.periodFinish()
    );
  }

  function testNotifyRewardAmount_WhenUsingAmountGreaterThanVaultBalance()
    external
  {
    fixture.tokenVault.setRewardsDuration(1);

    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_ProvidedRewardTooHigh()")
    );
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(TOKEN_VAULT_BALANCE.add(1 ether));
  }

  function testNotifyRewardAmount_WhenCallDuringRewardPeriod() external {
    fixture.tokenVault.setRewardsDuration(1 ether);

    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    // 10e18 / 1e18
    assertEq(10, fixture.tokenVault.rewardRate());
    assertEq(1, fixture.tokenVault.lastUpdateTime());
    assertEq(1, fixture.tokenVault.campaignStartBlock());
    assertEq(
      uint256(block.timestamp).add(1 ether),
      fixture.tokenVault.periodFinish()
    );

    vm.warp((0.5 ether));
    vm.roll(10000);

    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    // (10e18 + (((1e18 + 1) - 0.5e18) * 10)) / 1e18
    assertEq(15, fixture.tokenVault.rewardRate());
    assertEq(0.5 ether, fixture.tokenVault.lastUpdateTime());
    assertEq(10000, fixture.tokenVault.campaignStartBlock());
    assertEq(1.5 ether, fixture.tokenVault.periodFinish());
  }

  function testRewardPerToken_WhenTotalSupplyIsZero() external {
    fixture.tokenVault.setRewardsDuration(10000);

    // Set fee model here
    fixture.tokenVault.setMigrationOption(
      IMigrator(address(0)),
      IMigrator(address(0)),
      block.timestamp + 1,
      address(fixture.fakeFeeModel),
      0,
      address(0),
      0
    );

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(100000 ether);

    // making transaction to trigger reward update
    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    vm.warp(5001);

    vm.prank(ALICE);
    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);

    assertEq(0, fixture.tokenVault.totalSupply());

    // (((5001 - 1) * (100000e18 / 10000)) * 1e18) / 1000e18
    assertEq(50 ether, fixture.tokenVault.rewardPerToken());
  }

  function testRewardPerToken_WhenTotalSupplyIsNotZero() external {
    fixture.tokenVault.setRewardsDuration(10000);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(100000 ether);

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    vm.warp(5001);

    // (((5001 - 1) * (100000e18 / 10000)) * 1e18) / 1000e18
    assertEq(50 ether, fixture.tokenVault.rewardPerToken());

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    vm.warp(8001);
    assertEq(
      STAKE_AMOUNT_1000.add(STAKE_AMOUNT_1000),
      fixture.tokenVault.totalSupply()
    );

    // additional from previous rewardPerToken()
    // 50e18 + ((((8001 - 5001) * (100000e18 / 10000)) * 1e18) / 2000e18)
    assertEq(65 ether, fixture.tokenVault.rewardPerToken());
  }

  function testStake_WhenStakingIsAllowed() external {
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

  function testStake_WhenStakeAfterMigrated() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.expectEmit(true, true, true, true);
    emit Migrate(uint256(0), uint256(0));

    _simulateMigrate(1, 1, 10000, 0, 1 ether, TREASURY_FEE_RATE);

    vm.startPrank(ALICE);

    fixture.fakeStakingToken.approve(
      address(fixture.tokenVault),
      STAKE_AMOUNT_1000
    );

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    fixture.tokenVault.stake(STAKE_AMOUNT_1000);

    vm.stopPrank();
  }

  function testStake_WhenStakeWithZeroAmount() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotStakeZeroAmount()")
    );
    fixture.tokenVault.stake(0);

    vm.stopPrank();
  }

  function testWithdraw_WhenWithdrawalIsAllowed() external {
    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);

    // Set fee model here
    fixture.tokenVault.setMigrationOption(
      IMigrator(address(0)),
      IMigrator(address(0)),
      block.timestamp + 1,
      address(fixture.fakeFeeModel),
      0,
      address(0),
      0
    );

    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    fixture.fakeFeeModel.mockSetFee(0.02 ether);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(address(ALICE), 980 ether, 20 ether);

    vm.prank(ALICE);
    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);

    assertEq(0, fixture.tokenVault.totalSupply());
    assertEq(
      20 ether,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(20 ether, fixture.tokenVault.reserve());

    assertEq(980 ether, fixture.fakeStakingToken.balanceOf(address(ALICE)));
  }

  function testWithdraw_WhenWithdrawWithZeroAmount() external {
    fixture.fakeStakingToken.mint(address(ALICE), STAKE_AMOUNT_1000);

    vm.startPrank(ALICE);
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotWithdrawZeroAmount()")
    );
    fixture.tokenVault.withdraw(0);

    vm.stopPrank();
  }

  function testWithdraw_WhenWithdrawAfterMigrated() external {
    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    _simulateMigrate(1, 1, 10000, 0, 1 ether, TREASURY_FEE_RATE);

    vm.startPrank(ALICE);

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);

    vm.stopPrank();
  }

  function testReduceReserve_afterUserSuccessfullyWithdrawn_WithChaidIDNotEqTo1()
    external
  {
    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);

    // Set fee model here
    fixture.tokenVault.setMigrationOption(
      IMigrator(address(0)),
      IMigrator(address(0)),
      block.timestamp + 1,
      address(fixture.fakeFeeModel),
      0,
      address(0),
      0
    );

    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    assertEq(
      STAKE_AMOUNT_1000,
      fixture.fakeStakingToken.balanceOf(address(fixture.tokenVault))
    );
    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    fixture.fakeFeeModel.mockSetFee(0.02 ether);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(address(ALICE), 980 ether, 20 ether);

    vm.prank(ALICE);
    fixture.tokenVault.withdraw(STAKE_AMOUNT_1000);

    assertEq(20 ether, fixture.tokenVault.reserve());

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      IMigrator(address(fixture.fakeReserveMigrator)),
      block.timestamp + 1,
      address(fixture.fakeFeeModel),
      0,
      address(fixture.treasury),
      TREASURY_FEE_RATE
    );
    fixture.fakeReserveMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    uint256 balanceBefore = address(fixture.controller).balance;
    uint256 treasuryFee = (TREASURY_FEE_RATE * 20 ether) / 1 ether;
    uint256 executionFee = 20 ether - treasuryFee;

    vm.startPrank(address(fixture.controller));
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(address(fixture.treasury), 20 ether, treasuryFee);
    emit ReduceReserve(address(fixture.controller), 20 ether, executionFee);
    fixture.tokenVault.reduceReserve();
    vm.stopPrank();

    assertEq(0 ether, fixture.tokenVault.reserve());
    assertEq(treasuryFee, address(fixture.treasury).balance);
    assertEq(balanceBefore + executionFee, address(fixture.controller).balance);
  }

  function testReduceReserve_WhenCallingWithUnauthorizedAccount() external {
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotController()"));

    vm.prank(ALICE);
    fixture.tokenVault.reduceReserve();
  }

  function testClaimGov_WhenUserRewardIsAvailableAndUnclaimed() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(1 ether);
    fixture.tokenVault.setRewardsDuration(1 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    vm.warp(5001);

    // 10e18 / 1e18
    assertEq(10, fixture.tokenVault.rewardRate());

    // (5001 - 1) * 10 * 1e18 / 1000e18
    assertEq(50, fixture.tokenVault.rewardPerToken());

    vm.expectEmit(true, true, true, true);
    emit RewardPaid(address(ALICE), uint256(50000));

    vm.prank(ALICE);
    fixture.tokenVault.claimGov();

    assertEq(uint256(50000), fixture.fakeRewardToken.balanceOf(ALICE));
    assertEq(0, fixture.tokenVault.rewards(ALICE));
  }

  function testClaimGov_WhenThereAreNoRewardToClaim() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(1 ether);
    fixture.tokenVault.setRewardsDuration(1 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    vm.startPrank(ALICE);

    vm.warp(5000);

    fixture.tokenVault.claimGov();
    vm.stopPrank();

    assertEq(0, fixture.tokenVault.rewards(ALICE));
  }

  function testExit_WhenUserStakedAndAvailableRewardUnclaimed() external {
    vm.expectEmit(true, true, true, true);
    emit RewardsDurationUpdated(1 ether);
    fixture.tokenVault.setRewardsDuration(1 ether);

    vm.prank(fixture.rewardDistributor);
    vm.expectEmit(true, true, true, true);
    emit RewardAdded(10 ether);
    fixture.tokenVault.notifyRewardAmount(10 ether);

    fixture.fakeStakingToken.mint(ALICE, STAKE_AMOUNT_1000);
    _simulateStake(ALICE, STAKE_AMOUNT_1000);

    // Set fee model here
    fixture.tokenVault.setMigrationOption(
      IMigrator(address(0)),
      IMigrator(address(0)),
      block.timestamp + 1,
      address(fixture.fakeFeeModel),
      0,
      address(0),
      0
    );

    assertEq(STAKE_AMOUNT_1000, fixture.tokenVault.totalSupply());

    vm.warp(5001);

    // 10e18 / 1e18
    assertEq(10, fixture.tokenVault.rewardRate());

    // (5001 - 1) * 10 * 1e18 / 1000e18
    assertEq(uint256(50), fixture.tokenVault.rewardPerToken());

    vm.expectEmit(true, true, true, true);
    emit RewardPaid(address(ALICE), uint256(50000));

    vm.prank(ALICE);
    fixture.tokenVault.exit();

    assertEq(uint256(50000), fixture.fakeRewardToken.balanceOf(ALICE));
    assertEq(0, fixture.tokenVault.rewards(ALICE));

    assertEq(1000 ether, fixture.fakeStakingToken.balanceOf(ALICE));
  }

  function testMigrate_WhenParamsAreProperlySetUp() external {
    // users staking period
    fixture.fakeStakingToken.mint(ALICE, 500 ether);
    _simulateStake(ALICE, 500 ether);
    fixture.fakeStakingToken.mint(BOB, 1500 ether);
    _simulateStake(BOB, 1500 ether);
    assertEq(2000 ether, fixture.tokenVault.totalSupply());

    // vm.warp(10000);

    vm.expectEmit(true, true, true, true);
    emit Migrate(2000 ether, 2000 ether);

    _simulateMigrate(
      10000 ether,
      10000 ether,
      10000,
      0,
      1 ether,
      TREASURY_FEE_RATE
    );

    assertEq(2000 ether, address(fixture.tokenVault).balance);

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));

    vm.prank(fixture.controller);
    fixture.tokenVault.migrate();
  }

  function testMigrate_WhenChainIdIsInvalid() external {
    vm.chainId(1);

    vm.prank(fixture.controller);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_InvalidChainId()"));

    fixture.tokenVault.migrate();
  }

  function testMigrate_WhenCallerIsNotController() external {
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotController()"));

    fixture.tokenVault.migrate();
  }

  function testClaimETH_WhenUsersProperlyStaked() external {
    fixture.fakeStakingToken.mint(ALICE, 500 ether);
    _simulateStake(ALICE, 500 ether);
    fixture.fakeStakingToken.mint(BOB, 1500 ether);
    _simulateStake(BOB, 1500 ether);
    _simulateMigrate(
      10000 ether,
      10000 ether,
      10000,
      0,
      1 ether,
      TREASURY_FEE_RATE
    );

    assertEq(2000 ether, address(fixture.tokenVault).balance);

    vm.prank(BOB);
    fixture.tokenVault.claimETH();
    vm.prank(ALICE);
    fixture.tokenVault.claimETH();

    assertEq(500 ether, ALICE.balance);
    assertEq(1500 ether, BOB.balance);
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
