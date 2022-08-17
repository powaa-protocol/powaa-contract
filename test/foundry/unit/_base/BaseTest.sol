// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

abstract contract BaseTest is Test {
  address public constant ALICE = address(1);
  address public constant BOB = address(2);
  address public constant CATHY = address(3);
  address public constant EVE = address(4);

  ProxyAdmin internal proxyAdmin;

  constructor() {
    proxyAdmin = _setupProxyAdmin();
  }

  function _setupProxyAdmin() internal returns (ProxyAdmin) {
    return new ProxyAdmin();
  }
}
