// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./CurveLPVaultMigratorBase.t.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../../_mock/MockERC20.sol";
import "../../../_mock/MockWETH9.sol";

contract CurveLPVaultMigrator_TestExecute is CurveLPVaultMigratorBaseTest {
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

    _preMintFakeCurveStETHPoolLPUnderlyings(
      address(fakeCurveStethStableSwap),
      INITIAL_AMOUNT
    );
    _preMintFakeCurve3PoolLPUnderlyings(
      address(fakeCurve3PoolStableSwap),
      INITIAL_AMOUNT
    );
    _preMintFakeCurveTriCrypto2LPUnderlyings(
      address(fakeCurveTriCrypto2StableSwap),
      INITIAL_AMOUNT
    );
  }

  function test_WhenCallerIsNotWhitelistedContract() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "CurveLPVaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );
    migrator.execute(abi.encode(address(mockLpToken), uint24(0)));
  }

  function test_WhenCallWithWhitelistedContract_ToMigrateStETHPool() external {
    vm.prank(fakeStethLpToken.owner());
    MockERC20(fakeStethLpToken).mint(address(migrator), 10 ether);

    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveStethStableSwap.coins(0)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveStethStableSwap.coins(1)),
      1 ether
    );

    vm.prank(TOKEN_VAULT_STETH);
    migrator.execute(abi.encode(address(fakeStethLpToken), uint24(0)));

    assertEq(0, MockERC20(fakeStethLpToken).balanceOf(address(migrator)));
    assertEq(8 ether, address(TOKEN_VAULT_STETH).balance);
    assertEq(1 ether, address(GOV_LP_TOKEN_VAULT).balance);
    assertEq(1 ether, address(TREASURY).balance);
  }

  function test_WhenCallWithWhitelistedContract_ToMigrate3Pool() external {
    vm.prank(fake3PoolLpToken.owner());
    MockERC20(fake3PoolLpToken).mint(address(migrator), 10 ether);

    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurve3PoolStableSwap.coins(0)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurve3PoolStableSwap.coins(1)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurve3PoolStableSwap.coins(2)),
      1 ether
    );

    vm.prank(TOKEN_VAULT_3POOL);
    migrator.execute(abi.encode(address(fake3PoolLpToken), uint24(0)));

    assertEq(0, MockERC20(fake3PoolLpToken).balanceOf(address(migrator)));
    assertEq(8 ether, address(TOKEN_VAULT_3POOL).balance);
    assertEq(1 ether, address(GOV_LP_TOKEN_VAULT).balance);
    assertEq(1 ether, address(TREASURY).balance);
  }

  function test_WhenCallWithWhitelistedContract_ToMigrateTriCrypto2() external {
    vm.prank(fakeTriCrypto2LpToken.owner());
    MockERC20(fakeTriCrypto2LpToken).mint(address(migrator), 10 ether);

    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveTriCrypto2StableSwap.coins(0)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveTriCrypto2StableSwap.coins(1)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveTriCrypto2StableSwap.coins(2)),
      1 ether
    );

    vm.prank(TOKEN_VAULT_TRICRYPTO2);
    migrator.execute(abi.encode(address(fakeTriCrypto2LpToken), uint24(0)));

    assertEq(0, MockERC20(fakeTriCrypto2LpToken).balanceOf(address(migrator)));
    assertEq(8 ether, address(TOKEN_VAULT_TRICRYPTO2).balance);
    assertEq(1 ether, address(GOV_LP_TOKEN_VAULT).balance);
    assertEq(1 ether, address(TREASURY).balance);
  }

  function test_WhenCallWithWhitelistedContract_ToMigrateAllCurvePools()
    external
  {
    vm.prank(fakeStethLpToken.owner());
    MockERC20(fakeStethLpToken).mint(address(migrator), 10 ether);

    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveStethStableSwap.coins(0)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveStethStableSwap.coins(1)),
      1 ether
    );

    vm.prank(fake3PoolLpToken.owner());
    MockERC20(fake3PoolLpToken).mint(address(migrator), 10 ether);

    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurve3PoolStableSwap.coins(0)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurve3PoolStableSwap.coins(1)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurve3PoolStableSwap.coins(2)),
      1 ether
    );

    vm.prank(fakeTriCrypto2LpToken.owner());
    MockERC20(fakeTriCrypto2LpToken).mint(address(migrator), 10 ether);

    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveTriCrypto2StableSwap.coins(0)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveTriCrypto2StableSwap.coins(1)),
      1 ether
    );
    fakeUniswapRouter.mockSetSwapRate(
      address(fakeCurveTriCrypto2StableSwap.coins(2)),
      1 ether
    );

    vm.prank(TOKEN_VAULT_STETH);
    migrator.execute(abi.encode(address(fakeStethLpToken), uint24(0)));

    vm.prank(TOKEN_VAULT_3POOL);
    migrator.execute(abi.encode(address(fake3PoolLpToken), uint24(0)));

    vm.prank(TOKEN_VAULT_TRICRYPTO2);
    migrator.execute(abi.encode(address(fakeTriCrypto2LpToken), uint24(0)));

    assertEq(0, MockERC20(fakeStethLpToken).balanceOf(address(migrator)));
    assertEq(0, MockERC20(fake3PoolLpToken).balanceOf(address(migrator)));
    assertEq(0, MockERC20(fakeTriCrypto2LpToken).balanceOf(address(migrator)));
    assertEq(8 ether, address(TOKEN_VAULT_STETH).balance);
    assertEq(8 ether, address(TOKEN_VAULT_3POOL).balance);
    assertEq(8 ether, address(TOKEN_VAULT_TRICRYPTO2).balance);
    assertEq(3 ether, address(GOV_LP_TOKEN_VAULT).balance);
    assertEq(3 ether, address(TREASURY).balance);
  }
}
