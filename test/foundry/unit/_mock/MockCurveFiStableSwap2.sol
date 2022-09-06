// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "mock-contract/MockContract.sol";
import "./MockERC20.sol";
import "./MockCurveLpToken.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";

contract MockCurveFiStableSwap2 is MockContract {
  using SafeTransferLib for address;
  using SafeMath for uint256;

  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  MockCurveLpToken public pool;
  uint256[] exchangeRates;

  constructor(MockCurveLpToken _pool, uint256[2] memory _exchangeRates) {
    pool = _pool;
    exchangeRates = _exchangeRates;
  }

  function remove_liquidity(uint256 _amount, uint256[2] calldata min_uamounts)
    external
    returns (uint256[2] memory amounts)
  {
    min_uamounts;
    pool.transferFrom(msg.sender, address(this), _amount);

    uint256[2] memory returnAmounts;
    uint256 i;
    for (i = 0; i < exchangeRates.length; i++) {
      MockERC20 token = pool.tokens(i);
      if (address(token) == address(0)) {
        break;
      }

      uint256 swappedAmount = _amount.mul(exchangeRates[i]).div(1 ether);

      if (address(token) == ETH) {
        msg.sender.safeTransferETH(swappedAmount);
      } else {
        token.transfer(msg.sender, swappedAmount);
      }
      returnAmounts[i] = swappedAmount;
    }

    return (returnAmounts);
  }

  // TriCrypto2 function's index parameter is uint256
  function remove_liquidity_one_coin(
    uint256 _token_amount,
    uint256 i,
    uint256 _min_amount
  ) external {
    _mock_remove_liquidity_one_coin(_token_amount, i, _min_amount);
  }

  // stEth, 3Pool function's index parameter is int128
  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 _min_amount
  ) external {
    _mock_remove_liquidity_one_coin(
      _token_amount,
      uint256(int256(i)),
      _min_amount
    );
  }

  // TriCrypto2 function's index parameter is uint256
  function calc_withdraw_one_coin(uint256 _token_amount, uint256 i)
    external
    returns (uint256)
  {
    return _mock_calc_withdraw_one_coin(_token_amount, i);
  }

  // stEth, 3Pool function's index parameter is int128
  function calc_withdraw_one_coin(uint256 _token_amount, int128 i)
    external
    returns (uint256)
  {
    return _mock_calc_withdraw_one_coin(_token_amount, uint256(int256(i)));
  }

  function coins(uint256 i) external view returns (address) {
    MockERC20 token = pool.tokens(i);
    return address(token);
  }

  function balances(uint256 i) external view returns (uint256) {
    MockERC20 token = pool.tokens(i);
    return token.balanceOf(address(this));
  }

  function _mock_calc_withdraw_one_coin(uint256 _token_amount, uint256 index)
    internal
    returns (uint256)
  {
    index;

    uint256 i;
    uint256 totalSwappedAmount;
    for (i = 0; i < exchangeRates.length; i++) {
      MockERC20 token = pool.tokens(i);
      if (address(token) == address(0)) {
        break;
      }

      totalSwappedAmount += _token_amount.mul(exchangeRates[i]).div(1 ether);
    }

    return totalSwappedAmount;
  }

  function _mock_remove_liquidity_one_coin(
    uint256 _token_amount,
    uint256 i,
    uint256 _min_amount
  ) internal returns (uint256) {
    pool.transferFrom(msg.sender, address(this), _token_amount);
    uint256 totalAmount = _mock_calc_withdraw_one_coin(_token_amount, i);

    if (address(pool.tokens(i)) == ETH) {
      msg.sender.safeTransferETH(totalAmount);
    } else {
      pool.tokens(i).transfer(msg.sender, totalAmount);
    }
  }
}
