// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "./ChainlinkPriceOracleBase.t.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceOracle_TestPrice is ChainlinkPriceOracleBase {
  /// @dev Foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_WhenSetPriceFeed_shouldWork() external {
    address[] memory token0s = new address[](1);
    token0s[0] = USDC_ADDRESS;

    address[] memory token1s = new address[](1);
    token1s[0] = USD_ADDRESS;

    AggregatorV3Interface[][] memory allsoruces = new AggregatorV3Interface[][](
      1
    );
    AggregatorV3Interface[] memory sources = new AggregatorV3Interface[](1);
    sources[0] = AggregatorV3Interface(USDC_USD_ADDRESS);
    allsoruces[0] = sources;

    chainlinkPriceOracle.setPriceFeeds(token0s, token1s, allsoruces);

    (uint256 priceToken0, uint256 lastedUpdate) = chainlinkPriceOracle.getPrice(
      USDC_ADDRESS,
      USD_ADDRESS
    );

    assertEq(priceToken0, 1000059060000000000);
    assertEq(lastedUpdate, 1655723861);
  }

  function test_WhenGetPriceNoSource_shouldFail() external {
    vm.expectRevert(abi.encodeWithSignature("ChainlinkPriceOracle_NoSource()"));
    (uint256 priceToken0, uint256 lastedUpdate) = chainlinkPriceOracle.getPrice(
      USDC_ADDRESS,
      USD_ADDRESS
    );

    assertEq(priceToken0, 0);
    assertEq(lastedUpdate, 0);
  }

  function test_WhenSetPriceFeedNoMatchChainlink_shouldFail() external {
    address[] memory token0s = new address[](2);
    token0s[0] = USDC_ADDRESS;
    token0s[1] = DAI_ADDRESS;

    address[] memory token1s = new address[](1);
    token1s[0] = USD_ADDRESS;

    AggregatorV3Interface[][] memory allsoruces = new AggregatorV3Interface[][](
      1
    );
    AggregatorV3Interface[] memory sources = new AggregatorV3Interface[](1);
    sources[0] = AggregatorV3Interface(USDC_USD_ADDRESS);
    allsoruces[0] = sources;

    vm.expectRevert(
      abi.encodeWithSignature("ChainlinkPriceOracle_InconsistentLength()")
    );
    chainlinkPriceOracle.setPriceFeeds(token0s, token1s, allsoruces);
  }
}
