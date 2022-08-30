// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./UniswapV2GovLPVaultMigratorBase.t.sol";

contract UniswapV2GovLPVaultMigrator_TestGetApproximatedExecutionRewards is
  UniswapV2GovLPVaultMigratorBaseTest
{
  // UniswapV2GovLPVaultMigrator event
  event Execute(uint256 returnedETH, uint256 returnedBaseToken);

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function testGetAmountOut_WhenCallProperly() external {
    // 1e18 already minted in setup
    mockLp.mint(address(mockRouter), 199 ether);
    mockLp.mockSetReserves(10 ether, 20 ether);

    mockQuoter.mockSetQuoteToNativeRate(
      address(mockLp.mockGetBaseToken()),
      1 ether
    );

    bytes memory data = abi.encode(address(mockLp), uint256(100 ether));

    uint256 amountOut = uniswapV2GovLPVaultMigrator.getAmountOut(data);

    // we mocked the quotation rate, so the amount in will be exactly equals to the amount out

    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // baseToken
    // (10e18 * (100e18 / 200e18)) = 5e18

    // ETH
    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // (20e18 * (100e18 / 200e18)) = 10e18

    assertEq(15 ether, amountOut);
  }

  function test_WhenControllerFeeIsSet() external {
    bytes memory data = abi.encode(address(mockLp), uint256(100 ether));
    uint256 controllerFee = uniswapV2GovLPVaultMigrator
      .getApproximatedExecutionRewards(data);

    assertEq(0, controllerFee);
  }
}
