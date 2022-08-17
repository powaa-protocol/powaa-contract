// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockMigrator.sol";
import "../_mock/MockFeeModel.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";

abstract contract BaseTokenVaultFixture is BaseTest {
  uint256 public constant STAKE_AMOUNT_1000 = 1000 * 1e18;

  struct TokenVaultTestState {
    TokenVault tokenVault;
    address controller;
    address rewardDistributor;
    MockFeeModel fakeFeeModel;
    MockMigrator fakeMigrator;
    MockERC20 fakeRewardToken;
    MockERC20 fakeStakingToken;
    MockERC20 fakeGovToken;
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
    address _govToken,
    IFeeModel _withdrawalFeeModel,
    bool _isGovLpVault
  ) internal returns (TokenVault) {
    TokenVault _impl = new TokenVault(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      _controller,
      _govToken,
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
    _state.fakeGovToken = _setupFakeERC20("Gov Token", "GT");

    _state.tokenVault = _setupTokenVault(
      address(_state.rewardDistributor),
      address(_state.fakeRewardToken),
      address(_state.fakeStakingToken),
      address(_state.controller),
      address(_state.fakeGovToken),
      IFeeModel(address(_state.fakeFeeModel)),
      false
    );

    return _state;
  }
}
