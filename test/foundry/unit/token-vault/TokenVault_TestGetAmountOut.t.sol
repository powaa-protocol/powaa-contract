// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseTokenVaultFixture.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";

contract TokenVault_TestGetAmountOut is BaseTokenVaultFixture {
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

    fixture.tokenVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      IMigrator(address(fixture.fakeReserveMigrator)),
      block.number + 100,
      address(249146), // fee model is not necessary in this test
      uint24(0),
      address(1236287), // treasury is not necessary in this test
      0.2 ether
    );
  }

  function _simulateStake(address _user, uint256 _amount) internal {
    vm.startPrank(_user);
    fixture.fakeStakingToken.approve(address(fixture.tokenVault), _amount);

    vm.expectEmit(true, true, true, true);
    emit Staked(_user, _amount);

    fixture.tokenVault.stake(_amount);
    vm.stopPrank();
  }

  function test_WhenSomeTokenStaked() external {
    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    fixture.fakeStakingToken.mint(ALICE, 50 ether);
    _simulateStake(ALICE, 50 ether);
    fixture.fakeStakingToken.mint(BOB, 40 ether);
    _simulateStake(BOB, 40 ether);
    fixture.fakeStakingToken.mint(CATHY, 10 ether);
    _simulateStake(CATHY, 10 ether);

    assertEq(100 ether, fixture.tokenVault.totalSupply());

    uint256 amountOut = fixture.tokenVault.getAmountOut();
    assertEq(100 ether, amountOut);
  }

  function test_WhenNoTokenStaked() external {
    fixture.fakeMigrator.mockSetMigrateRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    assertEq(0 ether, fixture.tokenVault.totalSupply());

    uint256 amountOut = fixture.tokenVault.getAmountOut();
    assertEq(0 ether, amountOut);
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
