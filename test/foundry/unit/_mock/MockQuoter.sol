// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../../contracts/v0.8.16/interfaces/IFeeModel.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockQuoter is MockContract {
  function quoteExactInput(bytes memory path, uint256 amountIn)
    external
    returns (uint256 amountOut)
  {
    return 0;
  }

  function quoteExactInputSingle(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn,
    uint160 sqrtPriceLimitX96
  ) external returns (uint256 amountOut) {
    return 0;
  }

  function quoteExactOutput(bytes memory path, uint256 amountOut)
    external
    returns (uint256 amountIn)
  {
    return 0;
  }

  function quoteExactOutputSingle(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountOut,
    uint160 sqrtPriceLimitX96
  ) external returns (uint256 amountIn) {
    return 0;
  }
}
