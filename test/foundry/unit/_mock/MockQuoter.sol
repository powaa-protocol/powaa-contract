// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../../contracts/v0.8.16/interfaces/IFeeModel.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockQuoter is MockContract {
  using SafeMath for uint256;

  mapping(address => uint256) quoteToNativeRate;

  function mockSetQuoteToNativeRate(address _token, uint256 _rate) external {
    quoteToNativeRate[_token] = _rate;
  }
  
  // path, amountIn
  function quoteExactInput(bytes memory, uint256) 
    external
    returns (uint256 amountOut)
  {
    return 0;
  }

  function quoteExactInputSingle(
    address tokenIn,
    address, // tokenOut,
    uint24, // fee
    uint256 amountIn,
    uint160 // sqrtPriceLimitX96
  ) external returns (uint256 amountOut) {
    uint256 quoteAmount = amountIn.mul(quoteToNativeRate[tokenIn]).div(1 ether);
    return quoteAmount;
  }

  // path, amountOut
  function quoteExactOutput(bytes memory, uint256)
    external
    returns (uint256 amountIn)
  {
    return 0;
  }

  function quoteExactOutputSingle(
    address, //tokenIn
    address, //tokenOut
    uint24, //fee
    uint256, //amountOut
    uint160 //sqrtPriceLimitX96
  ) external returns (uint256 amountIn) {
    return 0;
  }
}
