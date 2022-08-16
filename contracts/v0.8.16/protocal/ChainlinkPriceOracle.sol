// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../interfaces/IPriceOracle.sol";

contract ChainlinkPriceOracle is OwnableUpgradeable, IPriceOracle {
  /// ---------------------------------------------------
  /// Errors
  /// ---------------------------------------------------
  error ChainlinkPriceOracle_InconsistentLength();
  error ChainlinkPriceOracle_InvalidPrice();
  error ChainlinkPriceOracle_NoSource();
  error ChainlinkPriceOracle_SourceExistedPair();
  error ChainlinkPriceOracle_SourceOverLimit();

  /// ---------------------------------------------------
  /// Configurable variables
  /// ---------------------------------------------------
  /// @dev Mapping from token0, token1 to sources
  mapping(address => mapping(address => mapping(uint256 => AggregatorV3Interface)))
    public priceFeeds;
  mapping(address => mapping(address => uint256)) public priceFeedCount;

  event SetPriceFeed(
    address indexed token0,
    address indexed token1,
    AggregatorV3Interface[] sources
  );

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();
  }

  /// @dev Set sources for multiple token pairs
  /// @param token0s Token0 address to set source
  /// @param token1s Token1 address to set source
  /// @param allSources source for the token pair
  function setPriceFeeds(
    address[] calldata token0s,
    address[] calldata token1s,
    AggregatorV3Interface[][] calldata allSources
  ) external onlyOwner {
    // Check
    if (token0s.length != token1s.length || token0s.length != allSources.length)
      revert ChainlinkPriceOracle_InconsistentLength();

    for (uint256 idx = 0; idx < token0s.length; idx++) {
      _setPriceFeed(token0s[idx], token1s[idx], allSources[idx]);
    }
  }

  /// @dev Set source for the token pair
  /// @param token0 Token0 address to set source
  /// @param token1 Token1 address to set source
  /// @param sources source for the token pair
  function _setPriceFeed(
    address token0,
    address token1,
    AggregatorV3Interface[] memory sources
  ) internal {
    // Check
    if (priceFeedCount[token1][token0] > 0)
      revert ChainlinkPriceOracle_SourceExistedPair();
    if (sources.length > 2) revert ChainlinkPriceOracle_SourceOverLimit();

    // Effect
    priceFeedCount[token0][token1] = sources.length;
    for (uint256 idx = 0; idx < sources.length; idx++) {
      priceFeeds[token0][token1][idx] = sources[idx];
    }

    emit SetPriceFeed(token0, token1, sources);
  }

  /// @dev Return the price of token0/token1, multiplied by 1e18
  /// @param token0 Token0 to set oracle sources
  /// @param token1 Token1 to set oracle sources
  function getPrice(address token0, address token1)
    external
    view
    override
    returns (uint256, uint256)
  {
    if (
      priceFeedCount[token0][token1] == 0 && priceFeedCount[token1][token0] == 0
    ) revert ChainlinkPriceOracle_NoSource();

    int256 _answer1 = 0;
    uint256 _lastUpdate1 = 0;
    int256 _answer2 = 0;
    uint256 _lastUpdate2 = 0;
    uint256 _decimals = 0;
    uint256 _price1 = 0;
    uint256 _price2 = 0;

    if (priceFeedCount[token0][token1] != 0) {
      (, _answer1, , _lastUpdate1, ) = priceFeeds[token0][token1][0]
        .latestRoundData();
      _decimals = uint256(priceFeeds[token0][token1][0].decimals());
      _price1 = (uint256(_answer1) * 1e18) / (10**_decimals);

      if (priceFeedCount[token0][token1] == 2) {
        (, _answer2, , _lastUpdate2, ) = priceFeeds[token0][token1][1]
          .latestRoundData();
        _decimals = uint256(priceFeeds[token0][token1][1].decimals());
        _price2 = (uint256(_answer2) * 1e18) / (10**_decimals);
        return (
          (_price1 * 1e18) / _price2,
          _lastUpdate2 < _lastUpdate1 ? _lastUpdate2 : _lastUpdate1
        );
      }

      return (_price1, _lastUpdate1);
    }

    (, _answer1, , _lastUpdate1, ) = priceFeeds[token1][token0][0]
      .latestRoundData();
    _decimals = uint256(priceFeeds[token1][token0][0].decimals());
    _price1 = ((10**_decimals) * 1e18) / uint256(_answer1);

    if (priceFeedCount[token1][token0] == 2) {
      (, _answer2, , _lastUpdate2, ) = priceFeeds[token1][token0][1]
        .latestRoundData();
      _decimals = uint256(priceFeeds[token1][token0][1].decimals());
      _price2 = ((10**_decimals) * 1e18) / uint256(_answer2);
      return (
        (_price1 * 1e18) / _price2,
        _lastUpdate2 < _lastUpdate1 ? _lastUpdate2 : _lastUpdate1
      );
    }

    return (_price1, _lastUpdate1);
  }
}
