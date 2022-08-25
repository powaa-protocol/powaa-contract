// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockETHLpToken.sol";
import "../_mock/MockUniswapV2Router01.sol";
import "../_mock/MockFeeModel.sol";
import "../_mock/MockMigrator.sol";
import "mock-contract/MockContract.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";

/// @title An abstraction of the UniswapV2GovLPVaultMigrator Testing contract, containing a scaffolding method for creating the fixture
abstract contract TokenVaultBaseTest is BaseTest {
  uint256 public constant STAKE_AMOUNT_1000 = 1000 * 1e18;
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  TokenVault internal tokenVault;
  address internal controller;
  address internal rewardDistributor;
  MockFeeModel internal fakeFeeModel;
  MockMigrator internal fakeMigrator;
  MockMigrator internal fakeReserveMigrator;
  MockERC20 internal fakeRewardToken;
  MockERC20 internal fakeStakingToken;
  MockETHLpToken internal fakeGovLpToken;

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
  event SetMigrationOption(
    IMigrator migrator,
    IMigrator reserveMigrator,
    uint256 campaignEndBlock,
    uint24 feePool
  );
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event ClaimETH(address indexed user, uint256 ethAmount);
  event ReduceReserve(uint256 reserveAmount, uint256 reducedETHAmount);

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    controller = address(123451234);
    rewardDistributor = address(123456789);
    fakeFeeModel = new MockFeeModel();
    fakeMigrator = new MockMigrator(false);
    fakeReserveMigrator = new MockMigrator(false);
    fakeRewardToken = _setupFakeERC20("Reward Token", "RT");
    fakeStakingToken = _setupFakeERC20("Staking Token", "ST");

    tokenVault = _setupTokenVault(
      address(rewardDistributor),
      address(fakeRewardToken),
      address(fakeStakingToken),
      address(controller),
      IFeeModel(address(fakeFeeModel)),
      false
    );
  }

  function _setupTokenVault(bool _isGovLpVault) internal {
    controller = address(123451234);
    rewardDistributor = address(123456789);
    fakeFeeModel = new MockFeeModel();
    fakeMigrator = new MockMigrator(false);
    fakeReserveMigrator = new MockMigrator(false);
    fakeRewardToken = _setupFakeERC20("Reward Token", "RT");
    fakeStakingToken = _setupFakeERC20("Staking Token", "ST");

    tokenVault = _setupTokenVault(
      address(rewardDistributor),
      address(fakeRewardToken),
      address(fakeStakingToken),
      address(controller),
      IFeeModel(address(fakeFeeModel)),
      _isGovLpVault
    );
  }

  function _setupTokenVaultLPTestState() internal {
    controller = address(123451234);
    rewardDistributor = address(123456789);
    fakeFeeModel = new MockFeeModel();
    fakeMigrator = new MockMigrator(true);
    fakeReserveMigrator = new MockMigrator(true);
    fakeRewardToken = _setupFakeERC20("Reward Token", "RT");

    fakeGovLpToken = new MockETHLpToken(IERC20(address(fakeRewardToken)));
    fakeStakingToken = MockERC20(payable(fakeGovLpToken));

    fakeGovLpToken.initialize("Gov LP Token", "G-LP");

    tokenVault = _setupTokenVault(
      address(rewardDistributor),
      address(fakeRewardToken),
      address(fakeGovLpToken),
      address(controller),
      IFeeModel(address(fakeFeeModel)),
      true
    );
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
    TokenVault _impl = new TokenVault();

    _impl.initialize(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      _controller,
      address(_withdrawalFeeModel),
      _isGovLpVault
    );

    return _impl;
  }
}
