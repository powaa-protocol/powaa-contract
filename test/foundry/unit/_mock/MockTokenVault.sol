// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../../../contracts/v0.8.16/interfaces/IFeeModel.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract MockTokenVault is MockContract, Ownable {
  using FixedPointMathLib for uint256;
  using SafeMath for uint256;

  address public rewardsDistribution;
  address public rewardsToken;
  IERC20 public stakingToken;
  bool public isGovLpVault;
  address public controller;

  MockTokenVault public immutable masterContract;

  uint256 public mockEthConversionRate;
  uint256 public mockControllerFeeRate;

  constructor() {
    masterContract = this;
  }

  function masterContractOwner() external view returns (address) {
    return masterContract.owner();
  }

  function initialize(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller
  ) public {
    rewardsToken = _rewardsToken;
    stakingToken = IERC20(_stakingToken);
    rewardsDistribution = _rewardsDistribution;
    controller = _controller;
    isGovLpVault = false;
  }

  function mockSetEthConversionRate(uint256 _rate) external returns (uint256) {
    mockEthConversionRate = _rate;
  }

  function getAmountOut() public returns (uint256) {
    uint256 tokenBalance = stakingToken.balanceOf(address(this));
    uint256 amountOut = mockEthConversionRate.mulWadDown(tokenBalance);

    return amountOut;
  }

  function mockSetControllerFeeRate(uint256 _rate) external returns (uint256) {
    mockControllerFeeRate = _rate;
  }

  function getApproximatedExecutionRewards() external returns (uint256) {
    uint256 amountOut = getAmountOut();
    uint256 executionReward = mockControllerFeeRate.mulWadDown(amountOut);

    return executionReward;
  }
}
