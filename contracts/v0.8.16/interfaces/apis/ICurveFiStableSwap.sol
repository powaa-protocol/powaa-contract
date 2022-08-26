// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

interface ICurveFiStableSwap {
  function remove_liquidity(uint256 _amount, uint256[4] calldata min_uamounts)
    external;

  function coins(uint128 i) external view returns (address);
}
