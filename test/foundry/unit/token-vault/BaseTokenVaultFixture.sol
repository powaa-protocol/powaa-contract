// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockMigrator.sol";
import "../_mock/MockFeeModel.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";

abstract contract BaseTokenVaultFixture is BaseTest {
  uint256 public constant STAKE_AMOUNT_1000 = 1000 * 1e18;

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
  event SetMigrationOption(IMigrator migrator, uint256 campaignEndBlock);
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event ClaimETH(address indexed user, uint256 ethAmount);

  struct TokenVaultTestState {
    TokenVault tokenVault;
    address controller;
    address rewardDistributor;
    MockFeeModel fakeFeeModel;
    MockMigrator fakeMigrator;
    MockERC20 fakeRewardToken;
    MockERC20 fakeStakingToken;
  }

  function _setupFakeERC20(string memory _name, string memory _symbol)
    internal
    returns (MockERC20)
  {
    MockERC20 _impl = new MockERC20();
    TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
      address(_impl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        bytes4(keccak256("initialize(string,string)")),
        _name,
        _symbol
      )
    );
    return MockERC20(payable(_proxy));
  }

  function _setupTokenVault(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller,
    IFeeModel _withdrawalFeeModel,
    bool _isGovLpVault
  ) internal returns (TokenVault) {
    TokenVault _impl = new TokenVault(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      _controller,
      _withdrawalFeeModel,
      _isGovLpVault
    );

    return _impl;
  }

  function _scaffoldTokenVaultTestState()
    internal
    returns (TokenVaultTestState memory)
  {
    TokenVaultTestState memory _state;
    _state.controller = address(123451234);
    _state.rewardDistributor = address(123456789);
    _state.fakeFeeModel = new MockFeeModel();
    _state.fakeMigrator = new MockMigrator();
    _state.fakeRewardToken = _setupFakeERC20("Reward Token", "RT");
    _state.fakeStakingToken = _setupFakeERC20("Staking Token", "ST");

    // we pre-minted plenty of native tokens for the mocked migrator
    // and pretend that it actually does the swapping when we executing migration
    vm.deal(address(_state.fakeMigrator), 10000000 ether);

    _state.tokenVault = _setupTokenVault(
      address(_state.rewardDistributor),
      address(_state.fakeRewardToken),
      address(_state.fakeStakingToken),
      address(_state.controller),
      IFeeModel(address(_state.fakeFeeModel)),
      false
    );

    return _state;
  }
}
