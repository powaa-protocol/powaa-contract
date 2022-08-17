// SPDX-License-Identifier: BUSL1.1
pragma solidity 0.8.16;

import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockMigrator is MockContract {
  function execute() external {
    fallbackImpl();
  }
}
