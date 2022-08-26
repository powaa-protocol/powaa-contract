// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "mock-contract/MockContract.sol";
import "./MockERC20.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract MockCurveFiStableSwap is MockContract {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;

  function remove_liquidity(uint256 _amount, uint256[] calldata min_uamounts)
    external
  {}

  function coins(int128 i) external view returns (address) {}
}
