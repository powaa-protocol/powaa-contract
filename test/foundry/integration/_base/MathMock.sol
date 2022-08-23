// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/Math.sol";

contract MathMock {
  function max(uint256 a, uint256 b) public pure returns (uint256) {
    return Math.max(a, b);
  }

  function min(uint256 a, uint256 b) public pure returns (uint256) {
    return Math.min(a, b);
  }

  function average(uint256 a, uint256 b) public pure returns (uint256) {
    return Math.average(a, b);
  }

  function ceilDiv(uint256 a, uint256 b) public pure returns (uint256) {
    return Math.ceilDiv(a, b);
  }
}