// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./Config.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ChainlinkPriceOracle } from "../../../contracts/v0.8.16/protocal/ChainlinkPriceOracle.sol";

import "./MathMock.sol";

/// @title A BaseTest serves as an abtraction for the testing contract containing all foundry testing functionalities.
/// @author powaa's engineering team
/**
  @dev please try to use the testing doubles based on these following rules - credit: Martin Fowler's test doubles
  - Dummy: objects are passed around but never actually used. Usually they are just used to fill parameter lists.
  - Fake: objects actually have working implementations, but usually take some shortcut which makes them not suitable for production (an in memory database is a good example).
  - Stubs: provide canned answers to calls made during the test, usually not responding at all to anything outside what's programmed in for the test.
  - Spies: are stubs that also record some information based on how they were called. One form of this might be an email service that records how many messages it was sent.
  - Mocks: very similar to stubs, but interaction-based rather than state-based. It simulates the behavior of the original object, and also records some information about how it was called.
 */
abstract contract BaseTest is Test, Config {
  /// @dev EVM init state
  uint64 public constant INIT_BLOCK_NUMBER = 15000000;
  uint64 public constant INIT_BLOCK_TIMESTAMP = 1655778500;

  address public constant ALICE = address(1);
  address public constant BOB = address(2);
  address public constant CATHY = address(3);
  address public constant EVE = address(4);

  /// @dev Test utils
  MathMock internal mathMock;
  ProxyAdmin internal proxyAdmin;

  /// @dev 3rd-party contracts
  ERC20 public USDC;

  constructor() {
    proxyAdmin = _setupProxyAdmin();
    mathMock = _setupMathMock();
  }

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    // assert init block number & block timestamp
    assertEq(block.number, INIT_BLOCK_NUMBER);
    assertEq(block.timestamp, INIT_BLOCK_TIMESTAMP);

    // setup: wrap addresses to entities
    USDC = ERC20(USDC_ADDRESS);
  }

  function _setupProxyAdmin() internal returns (ProxyAdmin) {
    return new ProxyAdmin();
  }

  function _setupMathMock() internal returns (MathMock) {
    return new MathMock();
  }

  function _setupChainlinkPriceOracle()
    internal
    returns (ChainlinkPriceOracle)
  {
    return new ChainlinkPriceOracle();
  }
}