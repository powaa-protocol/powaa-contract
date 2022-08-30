// SPDX-License-Identifier: BUSL1.1

pragma solidity 0.8.16;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockERC20.sol";

contract MockETHLpToken is MockERC20 {
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  IERC20 public token0;
  IERC20 public token1;

  struct LpReservesState {
    uint112 reserve0;
    uint112 reserve1;
    uint32 blockTimestampLast;
  }

  LpReservesState public reserves;

  constructor(IERC20 _token) {
    if (address(_token) < WETH9) {
      token0 = _token;
      token1 = IERC20(WETH9);
    } else {
      token0 = IERC20(WETH9);
      token1 = _token;
    }
  }

  function mockSetReserves(uint112 baseTokenReserve, uint112 ethReserve)
    public
  {
    uint112 _reserve0;
    uint112 _reserve1;
    if (address(token0) == WETH9) {
      _reserve0 = ethReserve;
      _reserve1 = baseTokenReserve;
    } else {
      _reserve0 = baseTokenReserve;
      _reserve1 = ethReserve;
    }

    reserves = MockETHLpToken.LpReservesState({
      reserve0: _reserve0,
      reserve1: _reserve1,
      blockTimestampLast: 0 // this is unused
    });
  }

  function mockGetBaseToken() public returns (address) {
    if (address(token0) == WETH9) {
      return address(token1);
    } else {
      return address(token0);
    }
  }

  function getReserves()
    external
    view
    returns (
      uint112,
      uint112,
      uint32
    )
  {
    return (reserves.reserve0, reserves.reserve1, reserves.blockTimestampLast);
  }
}
