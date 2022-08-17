// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "./interfaces/ITokenVault.sol";
import "./interfaces/IMigrator.sol";
import "./interfaces/IFeeModel.sol";
import "./interfaces/ILp.sol";

contract TokenVault is ITokenVault, ReentrancyGuard, Pausable, Ownable {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANT ========== */
  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  /* ========== STATE VARIABLES ========== */
  address public rewardsDistribution;
  address public rewardsToken;
  IERC20 public stakingToken;
  uint256 public periodFinish = 0;
  uint256 public rewardRate = 0;
  uint256 public rewardsDuration = 7 days;

  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;

  /* ========== STATE VARIABLES: Migration Options ========== */
  IFeeModel public withdrawalFeeModel;
  bool public isGovLpVault;
  bool public isMigrated;

  uint256 public campaignStartBlock;
  uint256 public campaignEndBlock;
  uint256 public reserve;

  IMigrator public migrator;
  address public controller;

  /* ========== EVENTS ========== */
  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);
  event RewardsDurationUpdated(uint256 newDuration);
  event Recovered(address token, uint256 amount);
  event SetMigrationOption(IMigrator migrator, uint256 campaignEndBlock);
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event ClaimETH(address indexed user, uint256 ethAmount);

  /* ========== ERRORS ========== */
  error TokenVault_CannotStakeZeroAmount();
  error TokenVault_CannotWithdrawZeroAmount();
  error TokenVault_ProvidedRewardTooHigh();
  error TokenVault_CannotWithdrawStakingToken();
  error TokenVault_RewardPeriodMustBeCompleted();
  error TokenVault_NotRewardsDistributionContract();
  error TokenVault_AlreadyMigrated();
  error TokenVault_NotYetMigrated();
  error TokenVault_InvalidChainId();
  error TokenVault_NotController();
  error TokenVault_LpTokenAddressInvalid();

  /* ========== CONSTRUCTOR ========== */
  constructor(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller,
    IFeeModel _withdrawalFeeModel,
    bool _isGovLpVault
  ) {
    rewardsToken = _rewardsToken;
    stakingToken = IERC20(_stakingToken);
    rewardsDistribution = _rewardsDistribution;
    controller = _controller;
    withdrawalFeeModel = _withdrawalFeeModel;
    isGovLpVault = _isGovLpVault;

    if (!isGovLpVault) return;

    // if isGovLPVault is true, then need to do sanity check if stakingToken is GOV_TOKEN-WETH LP
    if (_rewardsToken > WETH) {
      if (
        address(ILp(_stakingToken).token0()) != address(WETH) ||
        address(ILp(_stakingToken).token1()) != address(_rewardsToken)
      ) revert TokenVault_LpTokenAddressInvalid();
    } else {
      if (
        address(ILp(_stakingToken).token0()) != address(_rewardsToken) ||
        address(ILp(_stakingToken).token1()) != address(WETH)
      ) revert TokenVault_LpTokenAddressInvalid();
    }
  }

  /* ========== MODIFIERS ========== */

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  modifier onlyRewardsDistribution() {
    if (msg.sender != rewardsDistribution) {
      revert TokenVault_NotRewardsDistributionContract();
    }
    _;
  }

  modifier onlyController() {
    if (controller != msg.sender) {
      revert TokenVault_NotController();
    }
    _;
  }

  modifier whenNotMigrated() {
    if (isMigrated) {
      revert TokenVault_AlreadyMigrated();
    }
    _;
  }

  modifier whenMigrated() {
    if (!isMigrated) {
      revert TokenVault_NotYetMigrated();
    }
    _;
  }

  /* ========== VIEWS ========== */

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address _account) external view returns (uint256) {
    return _balances[_account];
  }

  function lastTimeRewardApplicable() public view returns (uint256) {
    return block.timestamp < periodFinish ? block.timestamp : periodFinish;
  }

  function rewardPerToken() public view returns (uint256) {
    if (_totalSupply == 0) {
      return rewardPerTokenStored;
    }
    return
      rewardPerTokenStored.add(
        lastTimeRewardApplicable()
          .sub(lastUpdateTime)
          .mul(rewardRate)
          .mul(1e18)
          .div(_totalSupply)
      );
  }

  function earned(address _account) public view returns (uint256) {
    return
      _balances[_account]
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
        .div(1e18)
        .add(rewards[_account]);
  }

  function GetRewardForDuration() external view returns (uint256) {
    return rewardRate.mul(rewardsDuration);
  }

  /* ========== ADMIN FUNCTIONS ========== */
  function setPaused(bool _paused) external onlyOwner {
    // Ensure we're actually changing the state before we do anything
    if (_paused == paused()) {
      return;
    }

    if (_paused) {
      _pause();
      return;
    }

    _unpause();
  }

  function setRewardsDistribution(address _rewardsDistribution)
    external
    onlyOwner
  {
    rewardsDistribution = _rewardsDistribution;
  }

  function setMigrationOption(IMigrator _migrator, uint256 _campaignEndBlock)
    external
    onlyOwner
  {
    migrator = _migrator;
    campaignEndBlock = _campaignEndBlock;

    emit SetMigrationOption(_migrator, _campaignEndBlock);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function migrate() external onlyController nonReentrant whenNotMigrated {
    if (block.chainid == 1) {
      revert TokenVault_InvalidChainId();
    }

    isMigrated = true;

    stakingToken.safeTransfer(address(migrator), _totalSupply);
    migrator.execute(address(stakingToken));

    emit Migrate(_totalSupply, address(this).balance);
  }

  function claimETH() external whenMigrated {
    uint256 claimable = _balances[msg.sender].mulDivDown(
      address(this).balance,
      _totalSupply
    );

    if (claimable == 0) {
      return;
    }

    msg.sender.safeTransferETH(claimable);

    emit ClaimETH(msg.sender, claimable);
  }

  function stake(uint256 _amount)
    external
    nonReentrant
    whenNotPaused
    whenNotMigrated
    updateReward(msg.sender)
  {
    if (_amount <= 0) revert TokenVault_CannotStakeZeroAmount();

    _totalSupply = _totalSupply.add(_amount);
    _balances[msg.sender] = _balances[msg.sender].add(_amount);
    stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

    emit Staked(msg.sender, _amount);
  }

  function withdraw(uint256 _amount)
    public
    nonReentrant
    whenNotMigrated
    updateReward(msg.sender)
  {
    if (_amount <= 0) revert TokenVault_CannotWithdrawZeroAmount();

    // actual withdrawal amount calculation with fee calculation
    uint256 actualWithdrawalAmount;
    {
      if (campaignStartBlock == 0) {
        // if campaignStartBlock == 0, then no rewards notified yet, hence campaign hasn't started
        actualWithdrawalAmount = _amount;
      } else {
        uint256 feeRate = withdrawalFeeModel.getFee(
          campaignStartBlock,
          block.number,
          campaignEndBlock
        );
        uint256 withdrawalFee = feeRate.mulWadDown(_amount);
        reserve += withdrawalFee;
        actualWithdrawalAmount = _amount - withdrawalFee;
      }
    }

    _totalSupply = _totalSupply.sub(_amount);
    _balances[msg.sender] = _balances[msg.sender].sub(_amount);

    stakingToken.safeTransfer(msg.sender, actualWithdrawalAmount);

    emit Withdrawn(msg.sender, _amount);
  }

  function claimGov() public nonReentrant updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      IERC20(rewardsToken).safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  function exit() external {
    withdraw(_balances[msg.sender]);
    claimGov();
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  function notifyRewardAmount(uint256 _reward)
    external
    onlyRewardsDistribution
    updateReward(address(0))
  {
    if (block.timestamp >= periodFinish) {
      rewardRate = _reward.div(rewardsDuration);
    } else {
      uint256 remaining = periodFinish.sub(block.timestamp);
      uint256 leftover = remaining.mul(rewardRate);
      rewardRate = _reward.add(leftover).div(rewardsDuration);
    }

    // Ensure the provided reward amount is not more than the balance in the contract.
    // This keeps the reward rate in the right range, preventing overflows due to
    // very high values of rewardRate in the earned and rewardsPerToken functions;
    // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
    uint256 balance = IERC20(rewardsToken).balanceOf(address(this));
    if (rewardRate > balance.div(rewardsDuration))
      revert TokenVault_ProvidedRewardTooHigh();

    lastUpdateTime = block.timestamp;
    campaignStartBlock = block.number;
    periodFinish = block.timestamp.add(rewardsDuration);
    emit RewardAdded(_reward);
  }

  // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
  function recoverERC20(address _tokenAddress, uint256 _tokenAmount)
    external
    onlyOwner
  {
    if (_tokenAddress == address(stakingToken))
      revert TokenVault_CannotWithdrawStakingToken();

    IERC20(_tokenAddress).safeTransfer(owner(), _tokenAmount);

    emit Recovered(_tokenAddress, _tokenAmount);
  }

  function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    if (block.timestamp <= periodFinish) {
      revert TokenVault_RewardPeriodMustBeCompleted();
    }

    rewardsDuration = _rewardsDuration;

    emit RewardsDurationUpdated(rewardsDuration);
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
