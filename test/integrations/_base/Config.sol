// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

contract Config {
  // Chain's
  uint256 public constant ETH_MAINNET = 1;

  // ERC20's
  address public constant USD_ADDRESS =
    0x0000000000000000000000000000000000000000;
  address public constant DAI_ADDRESS =
    0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address public constant USDC_ADDRESS =
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant wETH_ADDRESS =
    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  // Chainlink's
  address public constant USDC_USD_ADDRESS =
    0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
  address public constant DAI_USD_ADDRESS =
    0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
}
