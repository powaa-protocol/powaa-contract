// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

interface ICurveFiStableSwap {
  function remove_liquidity(uint256 _amount, uint256[2] calldata min_uamounts)
    external;

  function remove_liquidity(uint256 _amount, uint256[3] calldata min_uamounts)
    external;

  // TriCrypto2 function's index parameter is uint256
  function remove_liquidity_one_coin(
    uint256 _token_amount,
    uint256 i,
    uint256 _min_amount
  ) external;

  // stEth, 3Pool function's index parameter is int128
  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 _min_amount
  ) external;

  // TriCrypto2 function's index parameter is uint256
  function calc_withdraw_one_coin(uint256 _token_amount, uint256 i)
    external
    returns (uint256);

  // stEth, 3Pool function's index parameter is int128
  function calc_withdraw_one_coin(uint256 _token_amount, int128 i)
    external
    returns (uint256);

  function coins(uint256 i) external view returns (address);

  function balances(uint256 i) external view returns (uint256);
}
