// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./IBaseTokenVault.sol";

interface ITokenVault is IBaseTokenVault {
  function claimETH() external;

  function reduceReserve() external;

  function getApproximatedExecutionRewards() external returns (uint256);
}
