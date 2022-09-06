// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./CurveLPVaultMigratorBase.t.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../../_mock/MockERC20.sol";
import "../../../_mock/MockWETH9.sol";

contract CurveLPVaultMigrator_TestGetAmountOut is CurveLPVaultMigratorBaseTest {
  using SafeMath for uint256;
  using FixedPointMathLib for uint256;

  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );
  // more than enough amount
  uint256 public constant INITIAL_AMOUNT = 100000000000000 ether;

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();

    MockERC20(payable(WETH9)).mint(address(fakeUniswapRouter), INITIAL_AMOUNT);
  }

  function test_WhenCallProperly_WithStETHPool() external {
    bytes memory data = abi.encode(
      address(fakeStethLpToken),
      uint24(0),
      uint256(100 ether)
    );

    // we mock the exchange rate, so for 1 LP token swapper would receieve 0.5 token0 and 0.5 token1
    vm.prank(TOKEN_VAULT_STETH);
    assertEq(100 ether, migrator.getAmountOut(data));
  }

  function test_WhenCallProperly_With3Pool() external {
    // randomly mint to someone to generate lp token supply
    vm.prank(fake3PoolLpToken.owner());
    fake3PoolLpToken.mint(address(fakeQuoter), 200 ether);

    _preMintFakeCurve3PoolLPUnderlyings(
      address(fakeCurve3PoolStableSwap),
      50 ether
    );

    fakeQuoter.mockSetQuoteToNativeRate(
      address(fake3PoolLpToken.tokens(0)),
      1 ether
    );
    fakeQuoter.mockSetQuoteToNativeRate(
      address(fake3PoolLpToken.tokens(1)),
      1 ether
    );
    fakeQuoter.mockSetQuoteToNativeRate(
      address(fake3PoolLpToken.tokens(2)),
      1 ether
    );

    bytes memory data = abi.encode(
      address(fake3PoolLpToken),
      uint24(0),
      uint256(100 ether)
    );

    // we mocked the quotation rate, so the amount in will be exactly equals to the amount out

    // our token liquidity = (total_token_reserve * (our_ratio_in_total_supply))
    // token0
    // (50e18 * (100e18 / 200e18)) = 25e18

    // token1
    // (50e18 * (100e18 / 200e18)) = 25e18

    // token2
    // (50e18 * (100e18 / 200e18)) = 25e18

    vm.prank(TOKEN_VAULT_3POOL);
    assertEq(75 ether, migrator.getAmountOut(data));
  }

  function test_WhenCallProperly_WithTriCrypto2Pool() external {
    bytes memory data = abi.encode(
      address(fakeTriCrypto2LpToken),
      uint24(0),
      uint256(100 ether)
    );

    // we mock the exchange rate, so for 1 LP token swapper would receieve 0.4 token0, 0.3 token1, and 0.3 token1
    vm.prank(TOKEN_VAULT_TRICRYPTO2);
    assertEq(100 ether, migrator.getAmountOut(data));
  }
}
