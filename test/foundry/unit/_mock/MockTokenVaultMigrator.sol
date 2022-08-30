// SPDX-License-Identifier: BUSL1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";
import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract MockTokenVaultMigrator is MockContract {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;
  using SafeMath for uint256;

  mapping(address => uint256) private mockExchangeRate;
  uint256 private mockControllerFeeRate;

  function mockSetMigrateRate(address _token, uint256 _exchangeRate) external {
    mockExchangeRate[_token] = _exchangeRate;
  }

  function execute(bytes calldata _data) external {
    (address token, ) = abi.decode(_data, (address, uint24));

    uint256 tokenBalance = IERC20(token).balanceOf(address(this));
    uint256 migratedAmount = tokenBalance.mul(mockExchangeRate[token]).div(
      1 ether
    );

    msg.sender.safeTransferETH(migratedAmount);
  }

  function getAmountOut(bytes calldata _data) public returns (uint256) {
    (address token, uint24 poolFee, uint256 stakeAmount) = abi.decode(
      _data,
      (address, uint24, uint256)
    );

    uint256 amountOut = mockExchangeRate[token].mulWadDown(stakeAmount);

    return amountOut;
  }

  function mockSetControllerFeeRate(uint256 _rate) external returns (uint256) {
    mockControllerFeeRate = _rate;
  }

  function getApproximatedExecutionRewards(bytes calldata _data)
    external
    returns (uint256)
  {
    uint256 amountOut = getAmountOut(_data);
    uint256 executionReward = mockControllerFeeRate.mulWadDown(amountOut);

    return executionReward;
  }
}
