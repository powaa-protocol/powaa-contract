// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

interface ICurveFiStableSwap {
  function add_liquidity(uint256[] calldata uamounts, uint256 min_mint_amount)
    external;

  function remove_liquidity(uint256 _amount, uint256[] calldata min_uamounts)
    external;

  function remove_liquidity_imbalance(
    uint256[] calldata uamounts,
    uint256 max_burn_amount
  ) external;

  function coins(int128 i) external view returns (address);

  function underlying_coins(int128 i) external view returns (address);

  function underlying_coins() external view returns (address[] memory);

  function curve() external view returns (address);

  function token() external view returns (address);
}
