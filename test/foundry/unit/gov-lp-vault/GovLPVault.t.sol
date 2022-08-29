// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseGovLPVaultFixture.sol";
import "../../../../contracts/v0.8.16/GovLPVault.sol";

contract GovLPVault_Test is BaseGovLPVaultFixture {
  using SafeMath for uint256;

  uint256 public constant TOKEN_VAULT_BALANCE = 100000000 ether;
  uint256 public constant MIGRATOR_BALANCE = 100000000 ether;

  GovLPVaultTestState public fixture;

  /// @dev foundry's setUp method
  function setUp() public {
    GovLPVaultTestState memory _fixture = _scaffoldGovLPVaultLPTestState();

    fixture = GovLPVaultTestState({
      govLPVault: _fixture.govLPVault,
      controller: _fixture.controller,
      rewardDistributor: _fixture.rewardDistributor,
      fakeMigrator: _fixture.fakeMigrator,
      fakeRewardToken: _fixture.fakeRewardToken,
      fakeStakingToken: _fixture.fakeStakingToken,
      fakeGovLpToken: _fixture.fakeGovLpToken
    });

    // we pre-minted our gov token to be distributed later
    fixture.fakeRewardToken.mint(
      address(fixture.govLPVault),
      TOKEN_VAULT_BALANCE
    );

    // we pre-minted plenty of native tokens for the mocked migrator
    // and pretend that it actually does LP removal
    vm.deal(address(fixture.fakeMigrator), MIGRATOR_BALANCE / 2);
    _fixture.fakeRewardToken.mint(
      address(fixture.fakeMigrator),
      MIGRATOR_BALANCE / 2
    );
  }

  function _simulateStake(address _user, uint256 _amount) internal {
    fixture.fakeStakingToken.mint(_user, _amount);

    vm.startPrank(_user);
    fixture.fakeStakingToken.approve(address(fixture.govLPVault), _amount);

    vm.expectEmit(true, true, true, true);
    emit Staked(_user, _amount);

    fixture.govLPVault.stake(_amount);
    vm.stopPrank();
  }

  function _simulateMigrate(
    address _caller,
    uint256 _rewardDuration,
    uint256 _rewardAmount,
    uint256 _campaignEndBlock
  ) internal {
    // setting up
    fixture.govLPVault.setRewardsDuration(_rewardDuration);

    vm.prank(fixture.rewardDistributor);
    fixture.govLPVault.notifyRewardAmount(_rewardAmount);

    fixture.govLPVault.setMigrationOption(
      IMigrator(address(fixture.fakeMigrator)),
      _campaignEndBlock
    );

    vm.prank(_caller);
    fixture.govLPVault.migrate();
  }

  function test_WhenParamsAreProperlySetUp_WhenChainIDNotEq1() external {
    // users staking period
    fixture.fakeStakingToken.mint(ALICE, 500 ether);
    _simulateStake(ALICE, 500 ether);
    fixture.fakeStakingToken.mint(BOB, 1500 ether);
    _simulateStake(BOB, 1500 ether);
    assertEq(2000 ether, fixture.govLPVault.totalSupply());

    vm.expectEmit(true, true, true, true);
    emit Migrate(2000 ether, 1000 ether, 1000 ether);

    uint256 rewardTokenBefore = fixture.fakeRewardToken.balanceOf(
      address(fixture.govLPVault)
    );

    _simulateMigrate(
      address(fixture.controller),
      10000 ether,
      10000 ether,
      10000
    );

    assertEq(1000 ether, address(fixture.govLPVault).balance);
    assertEq(
      1000 ether,
      fixture.fakeRewardToken.balanceOf(address(fixture.govLPVault)) -
        rewardTokenBefore
    );

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));

    vm.prank(fixture.controller);
    fixture.govLPVault.migrate();
  }

  function test_WhenParamsAreProperlySetUp_WhenChainID1() external {
    // users staking period
    fixture.fakeStakingToken.mint(ALICE, 500 ether);
    _simulateStake(ALICE, 500 ether);
    fixture.fakeStakingToken.mint(BOB, 1500 ether);
    _simulateStake(BOB, 1500 ether);
    assertEq(2000 ether, fixture.govLPVault.totalSupply());

    vm.chainId(1);

    vm.expectEmit(true, true, true, true);
    emit Migrate(2000 ether, 1000 ether, 1000 ether);

    uint256 rewardTokenBefore = fixture.fakeRewardToken.balanceOf(
      address(fixture.govLPVault)
    );

    _simulateMigrate(address(this), 10000 ether, 10000 ether, 10000);

    assertEq(1000 ether, address(fixture.govLPVault).balance);
    assertEq(
      1000 ether,
      fixture.fakeRewardToken.balanceOf(address(fixture.govLPVault)) -
        rewardTokenBefore
    );

    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));

    fixture.govLPVault.migrate();
  }

  function test_WhenCallerIsNotAnOwner_WhenChainID1() external {
    vm.chainId(1);

    vm.prank(fixture.controller);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));

    fixture.govLPVault.migrate();
  }

  function test_WhenCallerIsNotController_WhenChainIDNotEq1() external {
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotController()"));

    fixture.govLPVault.migrate();
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
