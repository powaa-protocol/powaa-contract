// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./SushiSwapLPVaultMigratorBase.t.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import "../../../_mock/MockERC20.sol";
import "../../../_mock/MockWETH9.sol";

contract SushiSwapLPVaultMigrator_TestExecute is
  SushiSwapLPVaultMigratorBaseTest
{
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

    _setupMockWETH9(INITIAL_AMOUNT);

    // pre-minted relevant tokens to allow mock routers to fake doing the swap
    vm.deal(address(v2Router), INITIAL_AMOUNT);
    MockWETH9(payable(WETH9)).mint(address(v3Router), INITIAL_AMOUNT);
    mockBaseToken.mint(address(v2Router), INITIAL_AMOUNT);
  }

  function test_WhenCallerIsNotWhitelistedContract() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "SushiSwapLPVaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );
    migrator.execute(abi.encode(address(mockLpToken), uint24(0)));
  }

  function test_WhenExecute_withWhitelistTokenVault() external {
    migrator.whitelistTokenVault(address(this), true);

    mockLpToken.mint(address(migrator), 10 ether);

    uint256 balanceBefore = address(this).balance;

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Execute(8 ether, 1 ether, 1 ether);

    migrator.execute(abi.encode(address(mockLpToken), uint24(0)));

    uint256 balanceAfter = address(this).balance;

    assertEq(8 ether, balanceAfter.sub(balanceBefore));
    assertEq(1 ether, address(treasury).balance);
    assertEq(1 ether, address(govLPTokenVault).balance);

    assertEq(0, mockLpToken.balanceOf(address(migrator)));
    assertEq(0, mockBaseToken.balanceOf(address(migrator)));
  }

  function test_WhenExecute_withWhitelistTokenVault_Fuzzy(
    uint256 amount,
    uint256 lpTokenToBaseRate,
    uint256 lpTokenToEthRate,
    uint256 baseTokenToEthRate,
    uint256 govLPTokenVaultFeeRate,
    uint256 treasuryFeeRate
  ) external {
    amount = bound(amount, 1 ether, 10 ether);
    lpTokenToBaseRate = bound(lpTokenToBaseRate, 1 ether, 100 ether);
    lpTokenToEthRate = bound(lpTokenToEthRate, 1 ether, 100 ether);
    baseTokenToEthRate = bound(baseTokenToEthRate, 1 ether, 100 ether);

    // govLPTokenVaultFeeRate + treasuryFeeRate should not be more than 1e18
    govLPTokenVaultFeeRate = bound(govLPTokenVaultFeeRate, 1, 0.99 ether);
    treasuryFeeRate = bound(
      treasuryFeeRate,
      1,
      uint256(0.99 ether).sub(govLPTokenVaultFeeRate)
    );

    migrator = _setupMigrator(govLPTokenVaultFeeRate, treasuryFeeRate);
    v2Router.mockSetLpRemoveLiquidityRate(
      address(mockLpToken),
      lpTokenToBaseRate,
      lpTokenToEthRate
    );
    v3Router.mockSetSwapRate(address(mockBaseToken), baseTokenToEthRate);

    migrator.whitelistTokenVault(address(this), true);

    mockLpToken.mint(address(migrator), amount);

    uint256 baseAmountFromV2 = amount.mulWadDown(lpTokenToBaseRate);
    uint256 nativeAmountFromV2 = amount.mulWadDown(lpTokenToEthRate);
    uint256 nativeAmountFromV3 = baseAmountFromV2.mulWadDown(
      baseTokenToEthRate
    );
    uint256 totalNative = nativeAmountFromV2.add(nativeAmountFromV3);

    uint256 govLPTokenVaultFee = govLPTokenVaultFeeRate.mulWadDown(totalNative);
    uint256 treasuryFee = treasuryFeeRate.mulWadDown(totalNative);
    uint256 vaultReward = totalNative - govLPTokenVaultFee - treasuryFee;

    uint256 balanceBefore = address(this).balance;

    // Events should be correctly emitted
    vm.expectEmit(true, true, true, true);
    emit Execute(vaultReward, govLPTokenVaultFee, treasuryFee);

    migrator.execute(abi.encode(address(mockLpToken), uint24(0)));
    uint256 balanceAfter = address(this).balance;

    assertEq(vaultReward, balanceAfter.sub(balanceBefore));
    assertEq(treasuryFee, address(treasury).balance);
    assertEq(govLPTokenVaultFee, address(govLPTokenVault).balance);

    assertEq(0, mockLpToken.balanceOf(address(migrator)));
    assertEq(0, mockBaseToken.balanceOf(address(migrator)));
  }

  receive() external payable {}
}
