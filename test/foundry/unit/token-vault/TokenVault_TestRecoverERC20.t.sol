// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseTokenVaultFixture.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";

contract TokenVault_TestRecoverERC20 is BaseTokenVaultFixture {
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
    uint256 _exchangeToNativeRate
  ) internal {
    // setting up
    fixture.tokenVault.setRewardsDuration(_rewardDuration);

    vm.prank(fixture.rewardDistributor);
    fixture.tokenVault.notifyRewardAmount(_rewardAmount);

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      IMigrator(address(fixture.fakeReserveMigrator)),
      _campaignEndBlock,
      _feePool
    );

    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      _exchangeToNativeRate
    );

    vm.prank(fixture.controller);
    fixture.tokenVault.migrate();
  }

  function test_WhenCallProperly() external {
    fixture.tokenVault.recoverERC20(address(fixture.fakeRewardToken), 1 ether);

    assertEq(1 ether, fixture.fakeRewardToken.balanceOf(address(this)));
    assertEq(
      TOKEN_VAULT_BALANCE.sub(1 ether),
      fixture.fakeRewardToken.balanceOf(address(fixture.tokenVault))
    );
  }

  function test_WhenCallWithUnauthorizedAccount() external {
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotController()"));

    vm.prank(ALICE);
    fixture.tokenVault.recoverERC20(address(fixture.fakeRewardToken), 1 ether);
  }

  function test_WhenRecoverStakingToken() external {
    vm.expectRevert(
      abi.encodeWithSignature("TokenVault_CannotWithdrawStakingToken()")
    );

    fixture.tokenVault.recoverERC20(address(fixture.fakeStakingToken), 1 ether);
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
