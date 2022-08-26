// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockERC20.sol";

contract MockCurveLpToken is MockERC20 {
  address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  IERC20[] public tokens;

  constructor(IERC20[4] memory _tokens) {
    tokens = _tokens;
  }
}
