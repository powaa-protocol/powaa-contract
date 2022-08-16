// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../_base/BaseTest.sol";

import { ChainlinkPriceOracle } from "../../../contracts/v0.8.16/protocal/ChainlinkPriceOracle.sol";

abstract contract ChainlinkPriceOracleBase is BaseTest {
  ChainlinkPriceOracle public chainlinkPriceOracle;

  constructor() {
    proxyAdmin = _setupProxyAdmin();
    mathMock = _setupMathMock();
  }

  /// @dev Foundry's setUp method
  function setUp() public virtual override {
    super.setUp();
    chainlinkPriceOracle = _setupPriceOracle();
  }

  function _setupPriceOracle() internal returns (ChainlinkPriceOracle) {
    ChainlinkPriceOracle _impl = new ChainlinkPriceOracle();

    TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
      address(_impl),
      address(proxyAdmin),
      abi.encodeWithSelector(bytes4(keccak256("initialize()")))
    );

    return ChainlinkPriceOracle(address(_proxy));
  }
}
