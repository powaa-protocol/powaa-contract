// SPDX-License-Identifier: BUSL1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockMigrator is MockContract {
  using SafeTransferLib for address;
  using SafeMath for uint256;

  mapping(address => uint256) exchangeRate;

  function mockSetMigrateRate(address _token, uint256 _exchangeRate) external {
    exchangeRate[_token] = _exchangeRate;
  }

  function execute(address token) external {
    uint256 tokenBalance = IERC20(token).balanceOf(address(this));
    uint256 migratedAmount = tokenBalance.mul(exchangeRate[token]).div(1 ether);

    msg.sender.safeTransferETH(migratedAmount);
  }
}
