// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ControllerBase.t.sol";

contract Controller_TestMigration is ControllerBaseTest {
  address internal constant MOCK_REWARD_DISTRIBUTION = address(10);
  address internal constant MOCK_REWARD_TOKEN = address(11);
  address internal constant MOCK_WITHDRAWAL_FEE_MODEL = address(12);

  // Controller event
  event Migrate(address[] vaults);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function _deployVault(address _stakingToken, bool _isGovLPVault)
    internal
    returns (address)
  {
    // Vault can be deterministically get using reward token as a salt
    address deterministicAddress = controller.getDeterministicVault(
      address(mockTokenVaultImpl),
      _stakingToken
    );

    controller.deployDeterministicVault(
      address(mockTokenVaultImpl),
      MOCK_REWARD_DISTRIBUTION,
      MOCK_REWARD_TOKEN,
      _stakingToken,
      MOCK_WITHDRAWAL_FEE_MODEL,
      _isGovLPVault
    );

    return deterministicAddress;
  }

  function test_WhenMigrationVault_WhenNoGovLPVault() external {
    address stakingToken = address(13);

    // Deploy only token vault
    _deployVault(stakingToken, false);

    // Migration requires to have both token vault and gov LP vault
    vm.expectRevert(abi.encodeWithSignature("Controller_NoGovLPVault()"));
    controller.migrate();
  }

  function test_WhenMigrationVault_WithNoVaults() external {
    vm.expectRevert(abi.encodeWithSignature("Controller_NoVaults()"));
    controller.migrate();
  }

  function test_WhenMigrationVault_WhenTheCallerIsNotOwner() external {
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
    controller.migrate();
    vm.stopPrank();
  }

  function test_WhenMigrationVault_WhenAllParamsAreCorrect() external {
    address stakingToken = address(13);
    address govLPToken = address(14);
    address[] memory expectedMigratedVaults = new address[](2);

    // Deploy a token vault
    expectedMigratedVaults[0] = _deployVault(stakingToken, false);

    // Deploy a gov LP vault
    expectedMigratedVaults[1] = _deployVault(govLPToken, true);

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Migrate(expectedMigratedVaults);

    // Migration requires to have both token vault and gov LP vault
    controller.migrate();
  }

  function test_WhenMigrationVault_WhenAllParamsAreCorrect_WithFuzzyLengthOfTokenVaults(
    uint256 tokenVaultsLength
  ) external {
    // token vaults length is set between 1 and 100
    tokenVaultsLength = bound(tokenVaultsLength, 1, 100);
    uint256 startStakingToken = 13;
    address govLPToken = address(
      uint160(startStakingToken + tokenVaultsLength)
    );
    address[] memory expectedMigratedVaults = new address[](
      tokenVaultsLength + 1
    );

    // Deploy a token vaults
    for (uint256 i = 0; i < tokenVaultsLength; i++) {
      address stakingToken = address(uint160(startStakingToken + i));
      expectedMigratedVaults[i] = _deployVault(stakingToken, false);
    }

    // Deploy a gov LP vault
    expectedMigratedVaults[expectedMigratedVaults.length - 1] = _deployVault(
      govLPToken,
      true
    );

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Migrate(expectedMigratedVaults);

    // Migration requires to have both token vault and gov LP vault
    controller.migrate();
  }
}
