// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "../interfaces/IFeeModel.sol";
import "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract LinearFeeModel is IFeeModel {
  using SafeTransferLib for address;
  using FixedPointMathLib for uint256;

  uint256 public multiplierRate;
  uint256 public baseRate;

  event NewInterestParams(uint256 baseRate, uint256 multiplierRate);

  constructor(uint256 _baseRate, uint256 _multiplierRate) {
    baseRate = _baseRate;
    multiplierRate = _multiplierRate;

    emit NewInterestParams(baseRate, multiplierRate);
  }

  function _utilizationRate(
    uint256 _startBlock,
    uint256 _currentBlock,
    uint256 _endBlock
  ) private pure returns (uint256) {
    if (_startBlock == 0 || _currentBlock < _startBlock) {
      return 0;
    }

    if (_currentBlock >= _endBlock) return 1e18;

    uint256 passedBlock = _currentBlock - _startBlock;

    return passedBlock.divWadDown(_endBlock - _startBlock);
  }

  function getFeeRate(
    uint256 _startBlock,
    uint256 _currentBlock,
    uint256 _endBlock
  ) public view returns (uint256) {
    uint256 ur = _utilizationRate(_startBlock, _currentBlock, _endBlock);

    return ur.mulWadDown(multiplierRate) + baseRate;
  }
}
