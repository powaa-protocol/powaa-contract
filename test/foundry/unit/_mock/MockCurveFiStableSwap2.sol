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
      token.transfer(msg.sender, swappedAmount);
      returnAmounts[i] = swappedAmount;
    }

    return (returnAmounts);
  }

  function coins(uint256 i) external view returns (address) {
    MockERC20 token = pool.tokens(i);
    return address(token);
  }
}
