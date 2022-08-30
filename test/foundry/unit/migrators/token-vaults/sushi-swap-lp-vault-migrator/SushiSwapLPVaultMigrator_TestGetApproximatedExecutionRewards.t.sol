// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SushiSwapLPVaultMigratorBase.t.sol";
import "../../../_mock/MockETHLpToken.sol";

contract SushiSwapLPVaultMigrator_TestWhitelistTokenVault is
  SushiSwapLPVaultMigratorBaseTest
{
  // more than enough amount
  uint256 public constant INITIAL_AMOUNT = 100000000000000 ether;

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function testGetAmountOut_WhenCallProperly() external {
    mockLpToken.mint(address(fakeSushiSwapRouter), 200 ether);
    mockLpToken.mockSetReserves(10 ether, 20 ether);

    fakeQuoter.mockSetQuoteToNativeRate(
      address(mockLpToken.mockGetBaseToken()),
      1 ether
    );

    bytes memory data = abi.encode(
      address(mockLpToken),
      uint24(0),
      uint256(100 ether)
    );

    uint256 amountOut = migrator.getAmountOut(data);

    // we mocked the quotation rate, so the amount in will be exactly equals to the amount out

    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // baseToken
    // (10e18 * (100e18 / 200e18)) = 5e18

    // ETH
    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // (20e18 * (100e18 / 200e18)) = 10e18

    // 15 ether, as the quotation rate is mocked
    assertEq(15 ether, amountOut);
  }
  
  function testGetApproximatedExecutionRewards_WhenControllerFeeIsSet() external {
    mockLpToken.mint(address(fakeSushiSwapRouter), 200 ether);
    mockLpToken.mockSetReserves(10 ether, 20 ether);

    fakeQuoter.mockSetQuoteToNativeRate(
      address(mockLpToken.mockGetBaseToken()),
      1 ether
    );

    bytes memory data = abi.encode(
      address(mockLpToken),
      uint24(0),
      uint256(100 ether)
    );

    uint256 controllerFee = migrator.getApproximatedExecutionRewards(data);

    // we mocked the quotation rate, so the amount in will be exactly equals to the amount out

    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // baseToken
    // (10e18 * (100e18 / 200e18)) = 5e18

    // ETH
    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // (20e18 * (100e18 / 200e18)) = 10e18

    // controller fee is 50% deducted from the amount (15 ether)
    assertEq(7.5 ether, controllerFee);
  }
}
