// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

// Inheritance
import "./Owned.sol";

contract RewardsDistributionRecipient is Owned {
    address public rewardsDistribution;

    constructor(address _owner) Owned( _owner) {
    }

    function notifyRewardAmount(uint256 reward) external virtual;

    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, "Caller is not RewardsDistribution contract");
        _;
    }

    function setRewardsDistribution(address _rewardsDistribution) external onlyOwner {
        rewardsDistribution = _rewardsDistribution;
    }
}