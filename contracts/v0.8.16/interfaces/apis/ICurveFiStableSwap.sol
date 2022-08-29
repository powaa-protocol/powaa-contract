// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

interface ICurveFiStableSwap {
  function remove_liquidity(uint256 _amount, uint256[2] calldata min_uamounts)
    external;

  function remove_liquidity(uint256 _amount, uint256[3] calldata min_uamounts)
    external;

  function coins(uint256 i) external view returns (address);
}
