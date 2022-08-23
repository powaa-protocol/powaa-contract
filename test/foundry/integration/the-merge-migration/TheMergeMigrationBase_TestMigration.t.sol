// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "./TheMergeMigrationBase.t.sol";

/// @title An abstraction of the The merge migration scenario Testing contract, containing a scaffolding method for creating the fixture
/// @notice This testing scheme would cover only migration steps started with vault creation until claiming ETH
contract TheMergeMigrationBase_TestMigration is TheMergeMigrationBase {
  address[] public TOKEN_VAULT_MIGRATION_PARTICIPANTS = [ALICE, BOB];
  address[] public GOV_LP_VAULT_MIGRATION_PARTICIPANTS = [CAT, EVE];

  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event ReduceReserve(uint256 reserveAmount, uint256 reducedETHAmount);
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event Migrate(address[] vaults);
  event Execute(
    uint256 vaultReward,
    uint256 govLPTokenVaultReward,
    uint256 treasuryReward
  );
  event Execute(uint256 vaultReward);
  event ClaimETH(address indexed user, uint256 ethAmount);

  /// @dev Foundry's setUp method
  function setUp() public override {
    super.setUp();
    // distribute 1000 USDC for each TOKEN_VAULT_MIGRATION_PARTICIPANTS
    _distributeUSDC(TOKEN_VAULT_MIGRATION_PARTICIPANTS, 1000 * 1e6);

    // build up LP tokens for each GOV_LP_VAULT_MIGRATION_PARTICIPANTS
    _setupGovLPToken(GOV_LP_VAULT_MIGRATION_PARTICIPANTS, 100 ether, 100 ether);
  }

  function test_WithHappyCase() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000 * 1e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000 * 1e6);

    usdcTokenVault.stake(1000 * 1e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000 * 1e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000 * 1e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000 * 1e6);

    usdcTokenVault.stake(1000 * 1e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000 * 1e6);
    vm.stopPrank();

    // Cat Stakes ALL POWAA-ETH Univswap V2 LP Token to the contract
    // Cat's current LP balance = 100000e18 * 100e18 / 100000e18 = 100 LP
    vm.startPrank(CAT);
    powaaETHUniswapV2LP.approve(address(govLPVault), 100 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(CAT, 100 ether);

    govLPVault.stake(100 ether);

    assertEq(govLPVault.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve Stakes Half of POWAA-ETH Univswap V2 LP Token to the contract
    // EVE's current LP balance = 101000e18 * 100e18 / 101000e18 = 100 LP
    vm.startPrank(EVE);
    powaaETHUniswapV2LP.approve(address(govLPVault), 50 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(EVE, 50 ether);

    govLPVault.stake(50 ether);

    assertEq(govLPVault.balanceOf(EVE), 50 ether);
    vm.stopPrank();

    // Warp to the half of the campaign
    uint256 periodFinish = usdcTokenVault.periodFinish();
    uint256 campaignEndBlock = usdcTokenVault.campaignEndBlock();
    vm.roll(block.number + (campaignEndBlock - block.number) / 2);
    vm.warp(block.timestamp + (periodFinish - block.timestamp) / 2);

    // Bob suddenly wants to withdraw half of his stake
    // -> startBlock >>>> currentBlock (half) >>>> campaignEndBlock
    // -> 15300000 >>>> 15300000 + (15500000 - 15300000) / 2  >>>> 15500000
    // -> 15300000 >>>> 15300000 + 100000 = 15400000 >>>> 15500000
    // 100000 / 200000 = 1/2 of max multiplier = 1/2 * 2% = 1%
    // thus, Bob needs to pay the total fee of 500 * 1% = 5 USDC to the reserve
    vm.startPrank(BOB);
    uint256 bobUSDCBefore = USDC.balanceOf(BOB);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 495 * 1e6, 5 * 1e6);

    usdcTokenVault.withdraw(500 * 1e6);
    uint256 bobUSDCAfter = USDC.balanceOf(BOB);
    vm.stopPrank();

    // States should be updated correcetly
    assertEq(bobUSDCAfter - bobUSDCBefore, 495 * 1e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 500 * 1e6);
    assertEq(usdcTokenVault.reserve(), 5 * 1e6);

    // Reserve's owner try to reduce reserve so that reserve can be used as a gas
    // 5 USDC can be converted into 2873876295998942 =~ 0.002873876295998942 ETH
    uint256 ownerEthBalanceBefore = address(this).balance;

    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(5 * 1e6, 2873876295998942);

    usdcTokenVault.reduceReserve();
    uint256 ownerEthBalanceAfter = address(this).balance;
    assertEq(ownerEthBalanceAfter - ownerEthBalanceBefore, 2873876295998942);

    // Controller Accidentally Call migrate eventhough the time is not yet over
    vm.expectRevert(abi.encodeWithSignature("TokenVault_InvalidChainId()"));
    controller.migrate();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);
    vm.chainId(POW_ETH_MAINNET);

    // For USDC TokenVault, the total 1500 USDC can be swapped into 0.862160374848613355 ETH
    // 5% of 0.862160374848613355 =~ 0.043108017901645590 will be transferred to the treasury
    // another 5% of 0.862160374848613355 will =~ 0.043108017901645590 be transferred to the GovLPVault
    // hence, the total ETH that the usdcTokenVault should receive is 0.862160374848613355 - (0.043108017901645590 * 2) = 0.775944322229620639
    // -----
    // For GovLPVault, the total of 150 LP can be swapped into 299.326793383802621868 ETH
    // since it's GovLPVault, 299.326793383802621868 ETH will be transferred directly to the vault
    // hence, the total ETH that the GovLPVault should receive is 299.326793383802621868 ETH + 0.043108017901645590 ETH = 299.369901401704267458 ETH
    address[] memory vaults = new address[](2);
    vaults[0] = address(usdcTokenVault);
    vaults[1] = address(govLPVault);
    // Migrate USDC TokenVault
    vm.expectEmit(true, true, true, true);
    emit Execute(775944322229620639, 43108017901645590, 43108017901645590);
    vm.expectEmit(true, true, true, true);
    emit Migrate(1500 * 1e6, 775944322229620639);
    // Migrate GovLP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(299326793383802621868);
    vm.expectEmit(true, true, true, true);
    emit Migrate(150 ether, 299369901401704267458);
    vm.expectEmit(true, true, true, true);
    emit Migrate(vaults);

    controller.migrate();

    assertEq(TREASURY.balance, 43108017901645590);
    assertEq(usdcTokenVault.ethSupply(), address(usdcTokenVault).balance);
    assertEq(address(usdcTokenVault).balance, 775944322229620639);
    assertEq(govLPVault.ethSupply(), address(govLPVault).balance);
    assertEq(address(govLPVault).balance, 299369901401704267458);

    // Alice claims her ETH, since Alice owns 66.666% of the supply,
    // Alice would receive 1000 * 0.775944322229620639 / 1500 = 517296214819747092 =~ 0.517296214819747092 ETH
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 517296214819747092);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 517296214819747092);

    // Alice try to claims her ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(ALICE.balance, 517296214819747092);
    vm.stopPrank();

    // Bob claims her ETH, since Bob owns 33.333% of the supply,
    // Bob would receive 500 * 0.775944322229620639 / 1500 = 258648107409873546 =~ 0.258648107409873546 ETH
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 258648107409873546);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 258648107409873546);

    // Bob try to claims her ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(BOB.balance, 258648107409873546);
    vm.stopPrank();

    // Cat claims her ETH, since Cat owns 66.666% of the supply,
    // Cat would receive 100 * 299.369901401704267458 / 150 = 199579934267802844972 =~ 199.579934267802844972 ETH
    vm.startPrank(CAT);
    // CAT doesn't have 0 ether, need to reset her for good
    vm.deal(CAT, 0);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(CAT, 199579934267802844972);

    govLPVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(CAT), 0);
    assertEq(CAT.balance, 199579934267802844972);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETH();
    assertEq(CAT.balance, 199579934267802844972);
    vm.stopPrank();

    // Eve claims her ETH, since Eve owns 33.333% of the supply,
    // Eve would receive 50 * 299.369901401704267458 / 150 = 99789967133901422486 =~ 99.789967133901422486 ETH
    vm.startPrank(EVE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(EVE, 99789967133901422486);

    govLPVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(EVE), 0);
    assertEq(EVE.balance, 99789967133901422486);

    // Eve try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETH();
    assertEq(EVE.balance, 99789967133901422486);
    vm.stopPrank();
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
