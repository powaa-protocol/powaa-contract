// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "mock-contract/MockContract.sol";
import "./MockERC20.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";

contract MockUniswapV2Router01 is MockContract {
  using SafeTransferLib for address;

  function removeLiquidityETH(
    address, /** token */
    uint256, /** liquidity */
    uint256 amountTokenMin,
    uint256 amountETHMin,
    address, /** to */
    uint256 /** deadline */
  ) external pure returns (uint256 amountToken, uint256 amountETH) {
    return (amountTokenMin, amountETHMin);
  }

  function swapExactTokensForETH(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata, /** path */
    address, /** to */
    uint256 /** deadline */
  ) external payable returns (uint256[] memory amounts) {
    uint256[] memory amountOuts = new uint256[](1);
    amountOuts[0] = amountOutMin;
    msg.sender.safeTransferETH(amountIn);
    return (amountOuts);
  }
}
