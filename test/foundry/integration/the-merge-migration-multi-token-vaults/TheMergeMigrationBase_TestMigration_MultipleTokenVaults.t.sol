// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "./TheMergeMigrationMultiTokensBase.t.sol";

import "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/// @title An abstraction of the The merge migration scenario Testing contract, containing a scaffolding method for creating the fixture
/// @notice This testing scheme would cover only migration steps started with vault creation until claiming ETH
/// @dev Vault(s): USDC,  GovLPVault: POWAA-ETH
contract TheMergeMigrationBase_TestMigration_MultiTokenVaults is
  TheMergeMigrationMultiTokensBase
{
  using FixedPointMathLib for uint256;

  address[] public TOKEN_VAULT_MIGRATION_PARTICIPANTS = [ALICE, BOB];
  address[] public GOV_LP_VAULT_MIGRATION_PARTICIPANTS = [CAT, EVE];
  uint256 usdtETHLPAmountETHUsed;

  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount, uint256 fee);
  event ReduceReserve(
    address to,
    uint256 reserveAmount,
    uint256 reducedETHAmount
  );
  event Execute(
    uint256 vaultReward,
    uint256 treasuryReward,
    uint256 controllerReward,
    uint256 govLPTokenVaultReward
  );
  event Migrate(uint256 stakingTokenAmount, uint256 vaultETHAmount);
  event Migrate(
    uint256 stakingTokenAmount,
    uint256 returnETHAmount,
    uint256 returnPOWAAAmount
  );
  event Migrate(address[] vaults);
  event Execute(uint256 returnedETH, uint256 returnedBaseToken);
  event ClaimETH(address indexed user, uint256 ethAmount);
  event TransferFee(address beneficiary, uint256 fee);
  event ClaimETHPOWAA(
    address indexed user,
    uint256 claimableETH,
    uint256 claimablePOWAA
  );
  event RewardPaid(address indexed user, uint256 reward);
  event SetRegisterVault(address vault, bool isRegistered);

  /// @dev Foundry's setUp method
  function setUp() public override {
    super.setUp();
    // distribute 1000 USDC for each TOKEN_VAULT_MIGRATION_PARTICIPANTS
    _distributeUSDC(TOKEN_VAULT_MIGRATION_PARTICIPANTS, 1000e6);

    // create USDT-ETH LP Worth 1000USDT and 1000ETH
    (, usdtETHLPAmountETHUsed) = _setupLPToken(
      TOKEN_VAULT_MIGRATION_PARTICIPANTS,
      address(sushiswapRouter),
      USDT_PHILANTHROPIST,
      address(USDT),
      2000e6,
      1 ether
    );

    _distributeCurveLPToken(
      TOKEN_VAULT_MIGRATION_PARTICIPANTS,
      CURVE_3POOL_LP_OWNER,
      CURVE_3POOL_LP_ADDRESS,
      uint256(1000 ether)
    );
    _distributeCurveLPToken(
      TOKEN_VAULT_MIGRATION_PARTICIPANTS,
      CURVE_TRICRYPTO2_LP_OWNER,
      CURVE_TRICRYPTO2_LP_ADDRESS,
      uint256(1000 ether)
    );

    // build up LP tokens for each GOV_LP_VAULT_MIGRATION_PARTICIPANTS
    _setupGovLPToken(GOV_LP_VAULT_MIGRATION_PARTICIPANTS, 100 ether, 100 ether);
  }

  function test_WithHappyCase_WithETHPowChain() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000e6);

    usdcTokenVault.stake(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000e6);

    usdcTokenVault.stake(1000e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000e6);
    vm.stopPrank();

    // Bob and Alice have 0.000026239198060538e18 USDT-ETH Sushi LP
    uint256 aliceLPBalance = USDT_ETH_SUSHI_LP.balanceOf(ALICE);
    uint256 bobLPBalance = USDT_ETH_SUSHI_LP.balanceOf(BOB);

    // Alice Stakes her total USDT-ETH lp balance to the contract
    vm.startPrank(ALICE);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), aliceLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, aliceLPBalance);

    usdtEthSushiLpVault.stake(aliceLPBalance);
    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), aliceLPBalance);
    vm.stopPrank();

    // Bob Stakes his USDT-ETH LP Balance to the contract
    vm.startPrank(BOB);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), bobLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, bobLPBalance);

    usdtEthSushiLpVault.stake(bobLPBalance);

    assertEq(usdtEthSushiLpVault.balanceOf(BOB), bobLPBalance);
    vm.stopPrank();

    // ALICE & BOB ALSO STAKE IN CURVES POOL
    vm.startPrank(ALICE);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 25 ether);
    CURVE_3POOL_LP.approve(address(curve3PoolLpVault), 25 ether);
    curve3PoolLpVault.stake(25 ether);

    assertEq(curve3PoolLpVault.balanceOf(ALICE), 25 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 75 ether);
    CURVE_TRICRYPTO2_LP.approve(address(curveTriCrypto2LpVault), 75 ether);
    curveTriCrypto2LpVault.stake(75 ether);

    assertEq(curveTriCrypto2LpVault.balanceOf(ALICE), 75 ether);

    vm.stopPrank();

    vm.startPrank(BOB);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 75 ether);
    CURVE_3POOL_LP.approve(address(curve3PoolLpVault), 75 ether);
    curve3PoolLpVault.stake(75 ether);

    assertEq(curve3PoolLpVault.balanceOf(BOB), 75 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 25 ether);
    CURVE_TRICRYPTO2_LP.approve(address(curveTriCrypto2LpVault), 25 ether);
    curveTriCrypto2LpVault.stake(25 ether);

    assertEq(curveTriCrypto2LpVault.balanceOf(BOB), 25 ether);

    vm.stopPrank();

    assertEq(100 ether, curve3PoolLpVault.totalSupply());
    assertEq(100 ether, curveTriCrypto2LpVault.totalSupply());

    // Cat Stakes ALL POWAA-ETH Univswap V2 LP Token to the contract
    // Cat's current LP balance = 100000e18 * 100e18 / 100000e18 = 100 LP
    vm.startPrank(CAT);
    powaaETHUniswapV2LP.approve(address(govLPVault), 100 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(CAT, 100 ether);

    // given block timstamp now is 1659940505, after staking, last reward time will be 1659940505
    // total supply will be 100 ether
    govLPVault.stake(100 ether);
    assertEq(govLPVault.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve Stakes Half of POWAA-ETH Univswap V2 LP Token to the contract
    // EVE's current LP balance = 101000e18 * 100e18 / 101000e18 = 100 LP
    vm.startPrank(EVE);
    powaaETHUniswapV2LP.approve(address(govLPVault), 50 ether);
    vm.expectEmit(true, true, true, true);
    emit Staked(EVE, 50 ether);

    // given block timstamp now is 1659940505, after staking, last reward time will be 1659940505
    // total supply will be 150 ether
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
    // thus, Bob needs to pay the total fee of 500 * 1% = 5 USDC to the reserve, we would reduce reserve after the executor executes migration
    vm.startPrank(BOB);
    uint256 bobUSDCBefore = USDC.balanceOf(BOB);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 495e6, 5e6);

    usdcTokenVault.withdraw(500e6);
    uint256 bobUSDCAfter = USDC.balanceOf(BOB);
    vm.stopPrank();

    // States should be updated correcetly
    assertEq(bobUSDCAfter - bobUSDCBefore, 495e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    assertEq(usdcTokenVault.reserve(), 5e6);

    // Controller Accidentally Call migrate eventhough the time is not yet over
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);
    vm.chainId(POW_ETH_MAINNET);

    // For USDC TokenVault, the total 1500 USDC can be swapped into 0.862160374848613355 ETH
    // 5% of 0.862160374848613355 =~ 0.043108017901645590 will be transferred to the treasury
    // other 5% of 0.862160374848613355 will =~ 0.043108017901645590 be transferred to the GovLPVault
    // other 2% of 0.862160374848613355 will =~ 0.017243207160658236 be transferred to the Controller (and fund to Executor)
    // hence, the total ETH that the usdcTokenVault should receive is 0.862160374848613355 - (0.043108017901645590 * 2) - 0.017243207160658236 = 0.758701115068962403
    // -----
    // For USDT-ETH SUSHI LP TokenVault, the total 0.000052478396121076 LP (0.000026239198060538 LP for Alice and Bob) can be removed into ~2 ETH worth of USDC (3469.450221 USDC) and 1.999999998920837678 ETH
    // 3469.450221 USDC can be swapped into 1.993968467066810624 ETH,
    // thus, the result of removing liquidity + swap is 1.999999998920837678 + 1.993968467066810624 = 3.993968465987648302 ETH
    // 5% of 3.993968465987648302 =~ 0.199698423299382415 will be transferred to the treasury
    // other 5% of 3.993968465987648302 will =~ 0.199698423299382415 be transferred to the GovLPVault
    // other 2% of 3.993968465987648302 will =~ 0.079879369319752966 be transferred to the Controller (and fund to Executor)
    // hence, the total ETH that the usdcTokenVault should receive is 3.993968465987648302 - (0.199698423299382415 * 2) - 0.079879369319752966 = 3.514692250069130506
    // -----
    // For 3Pool Curve LP TokenVault, the total 100 LP (50 LP for Alice and Bob) can be removed into ~0.02 ETH (37.935500903191657811 DAI, 35.274198 USDC, 28.974253 USDT)
    // 3469.450221 USDC can be swapped into 1.993968467066810624 ETH,
    // 37.935500903191657811 DAI can be swapped for 0.021801096305316384 ETH
    // 35.274198 USDC can be swapped for 0.020274615839781213 ETH
    // 28.974253 USDT can be swapped for 0.016651771447530898 ETH
    // thus, the result of removing liquidity + swap is 0.021801096305316384 + 0.020274615839781213 + 0.016651771447530898 = 0.058727483592628495 ETH
    // 5% of 0.058727483592628495  =~ 0.002936374179631424 will be transferred to the treasury
    // other 5% of 0.058727483592628495 will =~ 0.002936374179631424 be transferred to the GovLPVault
    // other 2% of 0.058727483592628495 will =~ 0.001174549671852569 be transferred to the Controller (and fund to Executor)
    // hence, the total ETH that the usdcTokenVault should receive is 0.058727483592628495 - (0.002936374179631424 * 2) - 0.001174549671852569 = 0.051680185561513078
    // -----
    // For TriCrypto2 Curve LP TokenVault, the total 100 LP (50 LP for Alice and Bob) can be removed into ~20 ETH (35383.479029 USDT, 1.48306016 Wrapped BTC, 20.27468113890648075 Wrapped ETH)
    // 35383.479029 USDT can be swapped for 20.330745444445895838 ETH
    // 1.48306016 WBTC can be swapped for 20.157704113111638623 ETH
    // thus, the result of removing liquidity + swap is 20.330745444445895838 + 20.157704113111638623 + 20.27468113890648075 = 60.763130696464015211 ETH
    // 5% of 60.763130696464015211  =~ 3.03815653482320076 will be transferred to the treasury
    // other 5% of 60.763130696464015211 will =~ 3.03815653482320076 be transferred to the GovLPVault
    // other 2% of 60.763130696464015211 will =~ 1.215262613929280304 be transferred to the Controller (and fund to Executor)
    // hence, the total ETH that the usdcTokenVault should receive is 60.763130696464015211 - (3.03815653482320076 * 2) - 1.215262613929280304 = 53.471555012888333387
    // -----
    // For GovLPVault, the total of 150 LP canbe removed into 150 ETH and 150 POWAA
    // for ETH, since there is a 5% reward from USDC TokenVault as well, thus the total ETH that the govLPVault should receive is 150 + 0.043108017901645590 + 0.199698423299382415 = 150.242806441201028005
    address[] memory vaults = new address[](6);
    vaults[0] = address(usdcTokenVault);
    vaults[1] = address(usdcEthSushiLpVault);
    vaults[2] = address(usdtEthSushiLpVault);
    vaults[3] = address(curve3PoolLpVault);
    vaults[4] = address(curveTriCrypto2LpVault);
    vaults[5] = address(govLPVault);
    // Fund Money to the executer
    vm.deal(EXECUTOR, 10 ether);
    uint256 executerEthBalanceBefore = EXECUTOR.balance;
    vm.startPrank(EXECUTOR);
    // Migrate USDC TokenVault
    // 5 USDC from withdrawal fee can be converted into 2873876295998942 =~ 0.002873876295998942 ETH
    // 50% of 0.002873876295998942 ~= 0.001436938147999471 will be sent to treasury
    // the other 50% ~= 0.001436938147999471 will be sent to Controller (and send to the executor)
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(address(controller), 5e6, 0.001436938147999471 ether);
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(WITHDRAWAL_TREASURY, 5e6, 0.001436938147999471 ether);
    vm.expectEmit(true, true, true, true);
    emit Execute(
      0.758701115068962403 ether,
      0.043108017901645590 ether,
      0.017243207160658236 ether,
      0.043108017901645590 ether
    );
    vm.expectEmit(true, true, true, true);
    emit Migrate(1500e6, 0.758701115068962403 ether);
    // Migrate USDT-ETH LP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(
      3.514692250069130506 ether,
      0.199698423299382415 ether,
      0.079879369319752966 ether,
      0.199698423299382415 ether
    );
    vm.expectEmit(true, true, true, true);
    emit Migrate(0.000052478396121076 ether, 3.514692250069130506 ether);

    // Migrate 3Pool LP Vault
    vm.expectEmit(true, true, true, true);
    // total 58727483592628495
    emit Execute(
      0.051680185561513078 ether,
      0.002936374179631424 ether,
      0.001174549671852569 ether,
      0.002936374179631424 ether
    );
    vm.expectEmit(true, true, true, true);
    emit Migrate(100 ether, 0.051680185561513078 ether);

    // Migrate TriCrypto2 LP Vault
    vm.expectEmit(true, true, true, true);
    // total 60763130696464015211
    emit Execute(
      53.471555012888333387 ether,
      3.03815653482320076 ether,
      1.215262613929280304 ether,
      3.03815653482320076 ether
    );
    vm.expectEmit(true, true, true, true);
    emit Migrate(100 ether, 53.471555012888333387 ether);

    // Migrate GovLP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(150 ether, 150 ether);
    vm.expectEmit(true, true, true, true);
    emit Migrate(150 ether, 153.283899350203860189 ether, 150 ether);
    // Migrate Vaults Events
    vm.expectEmit(true, true, true, true);
    emit Migrate(vaults);

    controller.migrate();

    uint256 executerEthBalanceAfter = EXECUTOR.balance;
    // 50% of withdrawal fee will be distributed to the Executor treasury = 0.002873876295998942/2 = 0.001436938147999471 ETH
    // 2% of 0.862160374848613355 will =~ 0.017243207160658236 be transferred to the Controller (and fund to the Executor)
    // thus, the Executor shall has 0.001436938147999471 + 0.017243207160658236 + 0.079879369319752966 + 0.001174549671852569 + 1.215262613929280304 = 1.314996678229543546 ETH
    assertEq(
      executerEthBalanceAfter - executerEthBalanceBefore,
      1.314996678229543546 ether
    );
    // 50% of withdrawal fee will be distributed to the withdrawal treasury = 0.002873876295998942/2 = 0.001436938147999471 ETH
    assertEq(WITHDRAWAL_TREASURY.balance, 0.001436938147999471 ether);

    // Treasury balance = 0.043108017901645590(USDC vault) + 0.199698423299382415(USDT-ETH LP vault)
    // + 0.002936374179631424 (3Pool Vault) + 3.03815653482320076 (TriCrypto Vault)
    // = 3.283899350203860189
    assertEq(TREASURY.balance, 3.283899350203860189 ether);

    assertEq(usdcTokenVault.ethSupply(), address(usdcTokenVault).balance);
    assertEq(address(usdcTokenVault).balance, 0.758701115068962403 ether);
    assertEq(govLPVault.ethSupply(), address(govLPVault).balance);
    assertEq(address(govLPVault).balance, 153.283899350203860189 ether);
    assertEq(govLPVault.powaaSupply(), 150 ether);
    vm.stopPrank();

    // Alice claims her ETH, since Alice owns 66.666% of the supply,
    // Alice would receive 1000 * 0.758701115068962403 / 1500 =~ 0.505800743379308268 ETH
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 0.505800743379308268 ether);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 0.505800743379308268 ether);

    // Alice try to claims her ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(ALICE.balance, 0.505800743379308268 ether);
    vm.stopPrank();

    // Alice claims her ETH, since Alice owns 50% of the supply,
    // Alice would receive ETH 3.514692250069130506 / 2 = 1.757346125034565253 + 0.505800743379308268(from claimETH of USDC Vault) ETH = 2.263146868413873521
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 1.757346125034565253 ether);

    usdtEthSushiLpVault.claimETH();

    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 2.263146868413873521 ether);

    // Alice try to claims her ETH again, shouldn't be able to do so
    usdtEthSushiLpVault.claimETH();
    assertEq(ALICE.balance, 2.263146868413873521 ether);
    vm.stopPrank();

    // Alice claims her ETH, since Alice owns 25% of the supply,
    // Alice would receive 25 * 0.051680185561513078 / 100 =~ 0.012920046390378269 ETH
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 0.012920046390378269 ether);

    curve3PoolLpVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 2.27606691480425179 ether);

    // Alice try to claims her ETH again, shouldn't be able to do so
    curve3PoolLpVault.claimETH();
    assertEq(ALICE.balance, 2.27606691480425179 ether);
    vm.stopPrank();

    // Alice claims her ETH, since Alice owns 75% of the supply,
    // Alice would receive 75 * 53.471555012888333387 / 100 =~ 40.10366625966625004 ETH
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 40.10366625966625004 ether);

    curveTriCrypto2LpVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 42.37973317447050183 ether);

    // Alice try to claims her ETH again, shouldn't be able to do so
    curveTriCrypto2LpVault.claimETH();
    assertEq(ALICE.balance, 42.37973317447050183 ether);
    vm.stopPrank();

    // Bob claims his ETH, since Bob owns 33.333% of the supply,
    // Bob would receive 500 * 0.758701115068962403 / 1500 =~ 0.252900371689654134 ETH
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 0.252900371689654134 ether);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 0.252900371689654134 ether);

    // Bob try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    usdcTokenVault.withdraw(500e6);

    // Bob try to claims his ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(BOB.balance, 0.252900371689654134 ether);
    vm.stopPrank();

    // Bob claims his ETH, since Bob owns 50% of the supply,
    // Bob would receive ETH 3.514692250069130506 / 2 = 1.757346125034565253 + 0.252900371689654134(from claimETH of USDC Vault) ETH = 2.010246496724219387
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 1.757346125034565253 ether);

    usdtEthSushiLpVault.claimETH();

    assertEq(usdtEthSushiLpVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 2.010246496724219387 ether);

    // Bob try to claims his ETH again, shouldn't be able to do so
    usdtEthSushiLpVault.claimETH();
    assertEq(BOB.balance, 2.010246496724219387 ether);
    vm.stopPrank();

    // BOB claims his ETH, since BOB owns 25% of the supply,
    // BOB would receive 75 * 0.051680185561513078 / 100 =~ 0.038760139171134808 ETH
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 0.038760139171134808 ether);

    curve3PoolLpVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 2.049006635895354195 ether);

    // BOB try to claims his ETH again, shouldn't be able to do so
    curve3PoolLpVault.claimETH();
    assertEq(BOB.balance, 2.049006635895354195 ether);
    vm.stopPrank();

    // BOB claims his ETH, since BOB owns 75% of the supply,
    // BOB would receive 25 * 53.471555012888333387 / 100 =~ 13.367888753222083346 ETH
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 13.367888753222083346 ether);

    curveTriCrypto2LpVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 15.416895389117437541 ether);

    // BOB try to claims his ETH again, shouldn't be able to do so
    curveTriCrypto2LpVault.claimETH();
    assertEq(BOB.balance, 15.416895389117437541 ether);
    vm.stopPrank();

    // Cat claims her ETH, since Cat owns 66.666% of the supply,
    // Cat would receive 100 * 153.283899350203860189 / 150 =~ 102.189266233469240126 ETH
    // Cat would receive 100 * 150 / 150 =~ 100 POWAA
    // After a certain amount of time (7 days ~=  604800 sec)
    // 604800 * 10 POWWA = 6048000 total POWWA to be distributed
    // 6048000 POWAA / 150 LP = 40320 POWAA per 1 LP
    // Cat own 100 LP hence, 40320 * 100 = 4032000 POWAA + 100 POWAA from LP removal = 4032100 POWAA
    vm.startPrank(CAT);
    // CAT doesn't have 0 ether, need to reset her for good
    vm.deal(CAT, 0);
    vm.expectEmit(true, true, true, true);
    emit RewardPaid(CAT, 4032000 ether);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(CAT, 102.189266233469240126 ether, 100 ether);

    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(CAT), 0);

    assertEq(CAT.balance, 102.189266233469240126 ether);
    assertEq(POWAAToken.balanceOf(CAT), 4032100 ether);

    // Cat try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    govLPVault.withdraw(100e6);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(CAT.balance, 102.189266233469240126 ether);
    assertEq(POWAAToken.balanceOf(CAT), 4032100 ether);
    vm.stopPrank();

    // Eve claims her ETH, since Eve owns 33.333% of the supply,
    // Eve would receive 50 * 153.283899350203860189 / 150 =~ 51.094633116734620063 ETH
    // Eve would receive 50 * 150 / 150 =~ 50 POWAA
    vm.startPrank(EVE);
    // EVE doesn't have 0 ether, need to reset her for good
    vm.deal(EVE, 0);
    vm.expectEmit(true, true, true, true);
    emit RewardPaid(EVE, 2016000 ether);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(EVE, 51.094633116734620063 ether, 50 ether);

    // After a certain amount of time (7 days ~=  604800 sec)
    // 604800 * 10 POWWA = 6048000 total POWWA to be distributed
    // 6048000 POWAA / 150 LP = 40320 POWAA per 1 LP
    // Eve own 50 LP hence, 40320 * 50 = 2016000 POWAA + 50 POWAA from LP removal = 2016050 POWAA
    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(EVE), 0);
    assertEq(EVE.balance, 51.094633116734620063 ether);
    assertEq(POWAAToken.balanceOf(EVE), 2016050 ether);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(EVE.balance, 51.094633116734620063 ether);
    assertEq(POWAAToken.balanceOf(EVE), 2016050 ether);
    vm.stopPrank();
  }

  function test_WithHappyCase_WithETHPowChain_WithNonRegisterVault() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000e6);

    usdcTokenVault.stake(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000e6);

    usdcTokenVault.stake(1000e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000e6);
    vm.stopPrank();

    // Bob and Alice have 0.000026239198060538e18 USDT-ETH Sushi LP
    uint256 aliceLPBalance = USDT_ETH_SUSHI_LP.balanceOf(ALICE);
    uint256 bobLPBalance = USDT_ETH_SUSHI_LP.balanceOf(BOB);

    // Alice Stakes her total USDT-ETH lp balance to the contract
    vm.startPrank(ALICE);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), aliceLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, aliceLPBalance);

    usdtEthSushiLpVault.stake(aliceLPBalance);
    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), aliceLPBalance);
    vm.stopPrank();

    // Bob Stakes his USDT-ETH LP Balance to the contract
    vm.startPrank(BOB);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), bobLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, bobLPBalance);

    usdtEthSushiLpVault.stake(bobLPBalance);

    assertEq(usdtEthSushiLpVault.balanceOf(BOB), bobLPBalance);
    vm.stopPrank();

    // Cat Stakes ALL POWAA-ETH Univswap V2 LP Token to the contract
    // Cat's current LP balance = 100000e18 * 100e18 / 100000e18 = 100 LP
    vm.startPrank(CAT);
    powaaETHUniswapV2LP.approve(address(govLPVault), 100 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(CAT, 100 ether);

    // given block timstamp now is 1659940505, after staking, last reward time will be 1659940505
    // total supply will be 100 ether
    govLPVault.stake(100 ether);
    assertEq(govLPVault.balanceOf(CAT), 100 ether);
    vm.stopPrank();

    // Eve Stakes Half of POWAA-ETH Univswap V2 LP Token to the contract
    // EVE's current LP balance = 101000e18 * 100e18 / 101000e18 = 100 LP
    vm.startPrank(EVE);
    powaaETHUniswapV2LP.approve(address(govLPVault), 50 ether);
    vm.expectEmit(true, true, true, true);
    emit Staked(EVE, 50 ether);

    // given block timstamp now is 1659940505, after staking, last reward time will be 1659940505
    // total supply will be 150 ether
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
    // thus, Bob needs to pay the total fee of 500 * 1% = 5 USDC to the reserve, we would reduce reserve after the executor executes migration
    vm.startPrank(BOB);
    uint256 bobUSDCBefore = USDC.balanceOf(BOB);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 495e6, 5e6);

    usdcTokenVault.withdraw(500e6);
    uint256 bobUSDCAfter = USDC.balanceOf(BOB);
    vm.stopPrank();

    // States should be updated correcetly
    assertEq(bobUSDCAfter - bobUSDCBefore, 495e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    assertEq(usdcTokenVault.reserve(), 5e6);

    // Controller Accidentally Call migrate eventhough the time is not yet over
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);
    vm.chainId(POW_ETH_MAINNET);

    vm.expectEmit(true, true, true, true);
    emit SetRegisterVault(address(usdtEthSushiLpVault), false);
    controller.setRegisterVault(address(usdtEthSushiLpVault), false);

    // For USDC TokenVault, the total 1500 USDC can be swapped into 0.862160374848613355 ETH
    // 5% of 0.862160374848613355 =~ 0.043108017901645590 will be transferred to the treasury
    // other 5% of 0.862160374848613355 will =~ 0.043108017901645590 be transferred to the GovLPVault
    // other 2% of 0.862160374848613355 will =~ 0.017243207160658236 be transferred to the Controller (and fund to Executor)
    // hence, the total ETH that the usdcTokenVault should receive is 0.862160374848613355 - (0.043108017901645590 * 2) - 0.017243207160658236 = 0.758701115068962403
    // -----
    /// For USDC-ETH, no total supply, hence continue
    // -----
    // For USDT-ETH SUSHI LP TokenVault, it's been unregistered, hence no need to track this pool
    // -----
    // For GovLPVault, the total of 150 LP canbe removed into 150 ETH and 150 POWAA
    // for ETH, since there is a 5% reward from USDC TokenVault as well, thus the total ETH that the govLPVault should receive is 150 + 0.043108017901645590 + 0.199698423299382415 = 150.242806441201028005
    address[] memory vaults = new address[](4);
    vaults[0] = address(usdcTokenVault);
    vaults[1] = address(usdcEthSushiLpVault);
    vaults[2] = address(usdtEthSushiLpVault);
    vaults[3] = address(govLPVault);
    // Fund Money to the executer
    vm.deal(EXECUTOR, 10 ether);
    uint256 executerEthBalanceBefore = EXECUTOR.balance;
    vm.startPrank(EXECUTOR);
    // Migrate USDC TokenVault
    // 5 USDC from withdrawal fee can be converted into 2873876295998942 =~ 0.002873876295998942 ETH
    // 50% of 0.002873876295998942 ~= 0.001436938147999471 will be sent to treasury
    // the other 50% ~= 0.001436938147999471 will be sent to Controller (and send to the executor)
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(address(controller), 5e6, 0.001436938147999471 ether);
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(WITHDRAWAL_TREASURY, 5e6, 0.001436938147999471 ether);
    vm.expectEmit(true, true, true, true);
    emit Execute(
      0.758701115068962403 ether,
      0.043108017901645590 ether,
      0.017243207160658236 ether,
      0.043108017901645590 ether
    );
    vm.expectEmit(true, true, true, true);
    emit Migrate(1500e6, 0.758701115068962403 ether);
    // Migrate GovLP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(150 ether, 150 ether);
    vm.expectEmit(true, true, true, true);
    emit Migrate(150 ether, 150.043108017901645590 ether, 150 ether);
    // Migrate Vaults Events
    vm.expectEmit(true, true, true, true);
    emit Migrate(vaults);

    controller.migrate();

    uint256 executerEthBalanceAfter = EXECUTOR.balance;
    // 50% of withdrawal fee will be distributed to the Executor treasury = 0.002873876295998942/2 = 0.001436938147999471 ETH
    // 2% of 0.862160374848613355 will =~ 0.017243207160658236 be transferred to the Controller (and fund to the Executor)
    // thus, the Executor shall has 0.001436938147999471 + 0.017243207160658236 = 0.018680145308657707 ETH
    assertEq(
      executerEthBalanceAfter - executerEthBalanceBefore,
      0.018680145308657707 ether
    );
    // 50% of withdrawal fee will be distributed to the withdrawal treasury = 0.002873876295998942/2 = 0.001436938147999471 ETH
    assertEq(WITHDRAWAL_TREASURY.balance, 0.001436938147999471 ether);

    assertEq(TREASURY.balance, 0.043108017901645590 ether);
    assertEq(usdcTokenVault.ethSupply(), address(usdcTokenVault).balance);
    assertEq(address(usdcTokenVault).balance, 0.758701115068962403 ether);
    assertEq(govLPVault.ethSupply(), address(govLPVault).balance);
    assertEq(address(govLPVault).balance, 150.043108017901645590 ether);
    assertEq(govLPVault.powaaSupply(), 150 ether);
    vm.stopPrank();

    // Alice claims her ETH, since Alice owns 66.666% of the supply,
    // Alice would receive 1000 * 0.758701115068962403 / 1500 =~ 0.505800743379308268 ETH
    vm.startPrank(ALICE);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(ALICE, 0.505800743379308268 ether);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    assertEq(ALICE.balance, 0.505800743379308268 ether);

    // Alice try to claims her ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(ALICE.balance, 0.505800743379308268 ether);
    vm.stopPrank();

    // Bob claims his ETH, since Bob owns 33.333% of the supply,
    // Bob would receive 500 * 0.758701115068962403 / 1500 =~ 0.252900371689654134 ETH
    vm.startPrank(BOB);
    vm.expectEmit(true, true, true, true);
    emit ClaimETH(BOB, 0.252900371689654134 ether);

    usdcTokenVault.claimETH();

    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    assertEq(BOB.balance, 0.252900371689654134 ether);

    // Bob try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    usdcTokenVault.withdraw(500e6);

    // Bob try to claims his ETH again, shouldn't be able to do so
    usdcTokenVault.claimETH();
    assertEq(BOB.balance, 0.252900371689654134 ether);
    vm.stopPrank();

    // Cat claims her ETH, since Cat owns 66.666% of the supply,
    // Cat would receive 100 * 150.043108017901645590 / 150 =~ 100.028738678601097060 ETH
    // Cat would receive 100 * 150 / 150 =~ 100 POWAA
    vm.startPrank(CAT);
    // CAT doesn't have 0 ether, need to reset her for good
    vm.deal(CAT, 0);
    vm.expectEmit(true, true, true, true);
    emit RewardPaid(CAT, 4032000 ether);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(CAT, 100.028738678601097060 ether, 100 ether);

    // After a certain amount of time (7 days ~=  604800 sec)
    // 604800 * 10 POWWA = 6048000 total POWWA to be distributed
    // 6048000 POWAA / 150 LP = 40320 POWAA per 1 LP
    // Cat own 100 LP hence, 40320 * 100 = 4032000 POWAA + 100 POWAA from LP removal = 4032100 POWAA
    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(CAT), 0);
    assertEq(CAT.balance, 100.028738678601097060 ether);
    assertEq(POWAAToken.balanceOf(CAT), 4032100 ether);

    // Cat try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    govLPVault.withdraw(100e6);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(CAT.balance, 100.028738678601097060 ether);
    assertEq(POWAAToken.balanceOf(CAT), 4032100 ether);
    vm.stopPrank();

    // Eve claims her ETH, since Eve owns 33.333% of the supply,
    // Eve would receive 50 * 150.043108017901645590 / 150 =~ 50.014369339300548530 ETH
    // Eve would receive 50 * 150 / 150 =~ 50 POWAA
    vm.startPrank(EVE);
    // EVE doesn't have 0 ether, need to reset her for good
    vm.deal(EVE, 0);
    vm.expectEmit(true, true, true, true);
    emit RewardPaid(EVE, 2016000 ether);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(EVE, 50.014369339300548530 ether, 50 ether);

    // After a certain amount of time (7 days ~=  604800 sec)
    // 604800 * 10 POWWA = 6048000 total POWWA to be distributed
    // 6048000 POWAA / 150 LP = 40320 POWAA per 1 LP
    // Eve own 50 LP hence, 40320 * 50 = 2016000 POWAA + 50 POWAA from LP removal = 2016050 POWAA
    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(EVE), 0);
    assertEq(EVE.balance, 50.014369339300548530 ether);
    assertEq(POWAAToken.balanceOf(EVE), 2016050 ether);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(EVE.balance, 50.014369339300548530 ether);
    assertEq(POWAAToken.balanceOf(EVE), 2016050 ether);
    vm.stopPrank();
  }

  function test_WithHappyCase_WithETHPosChain() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000e6);

    usdcTokenVault.stake(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000e6);

    usdcTokenVault.stake(1000e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000e6);
    vm.stopPrank();

    // Bob and Alice have 0.000026239198060538e18 USDT-ETH Sushi LP
    uint256 aliceLPBalance = USDT_ETH_SUSHI_LP.balanceOf(ALICE);
    uint256 bobLPBalance = USDT_ETH_SUSHI_LP.balanceOf(BOB);

    // Alice Stakes her total USDT-ETH lp balance to the contract
    vm.startPrank(ALICE);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), aliceLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, aliceLPBalance);

    usdtEthSushiLpVault.stake(aliceLPBalance);
    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), aliceLPBalance);
    vm.stopPrank();

    // Bob Stakes his USDT-ETH LP Balance to the contract
    vm.startPrank(BOB);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), bobLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, bobLPBalance);

    usdtEthSushiLpVault.stake(bobLPBalance);

    assertEq(usdtEthSushiLpVault.balanceOf(BOB), bobLPBalance);
    vm.stopPrank();

    // ALICE & BOB ALSO STAKE IN CURVES POOL
    vm.startPrank(ALICE);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 25 ether);
    CURVE_3POOL_LP.approve(address(curve3PoolLpVault), 25 ether);
    curve3PoolLpVault.stake(25 ether);

    assertEq(curve3PoolLpVault.balanceOf(ALICE), 25 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 75 ether);
    CURVE_TRICRYPTO2_LP.approve(address(curveTriCrypto2LpVault), 75 ether);
    curveTriCrypto2LpVault.stake(75 ether);

    assertEq(curveTriCrypto2LpVault.balanceOf(ALICE), 75 ether);

    vm.stopPrank();

    vm.startPrank(BOB);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 75 ether);
    CURVE_3POOL_LP.approve(address(curve3PoolLpVault), 75 ether);
    curve3PoolLpVault.stake(75 ether);

    assertEq(curve3PoolLpVault.balanceOf(BOB), 75 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 25 ether);
    CURVE_TRICRYPTO2_LP.approve(address(curveTriCrypto2LpVault), 25 ether);
    curveTriCrypto2LpVault.stake(25 ether);

    assertEq(curveTriCrypto2LpVault.balanceOf(BOB), 25 ether);

    vm.stopPrank();

    assertEq(100 ether, curve3PoolLpVault.totalSupply());
    assertEq(100 ether, curveTriCrypto2LpVault.totalSupply());

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
    // thus, Bob needs to pay the total fee of 500 * 1% = 5 USDC to the reserve, we would reduce reserve after the executor executes migration
    vm.startPrank(BOB);
    uint256 bobUSDCBefore = USDC.balanceOf(BOB);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 495e6, 5e6);

    usdcTokenVault.withdraw(500e6);
    uint256 bobUSDCAfter = USDC.balanceOf(BOB);
    vm.stopPrank();

    // States should be updated correcetly
    assertEq(bobUSDCAfter - bobUSDCBefore, 495e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    assertEq(usdcTokenVault.reserve(), 5e6);

    // Controller Accidentally Call migrate eventhough the time is not yet over
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);

    // Controller Accidentally Call migrate in ETH POS
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    controller.migrate();

    // Block number has been passed the migration phase
    vm.roll(campaignEndBlock + 1);

    // Reserve's owner try to reduce reserve so that reserve can be used as a gas
    // 5 USDC can be converted into 2873876295998942 =~ 0.002873876295998942 ETH
    uint256 withdrawalTreasuryEthBalanceBefore = WITHDRAWAL_TREASURY.balance;
    vm.expectEmit(true, true, true, true);
    emit ReduceReserve(WITHDRAWAL_TREASURY, 5e6, 0.002873876295998942 ether);

    usdcTokenVault.reduceReserve();
    uint256 withdrawalTreasuryEthBalanceAfter = WITHDRAWAL_TREASURY.balance;
    assertEq(
      withdrawalTreasuryEthBalanceAfter - withdrawalTreasuryEthBalanceBefore,
      0.002873876295998942 ether
    );

    // Alice could not claim ETH since it's ETH POS, no migration happens here
    vm.startPrank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    usdcTokenVault.claimETH();

    // Alice try to withdraw, she should be able to withdraw all staking tokens
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(ALICE, 1000e6, 0);
    usdcTokenVault.withdraw(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 0);
    vm.stopPrank();

    // Bob could not claim ETH since it's ETH POS, no migration happens here
    vm.startPrank(BOB);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    usdcTokenVault.claimETH();

    // Bob try to withdraw, he should be able to withdraw all staking tokens
    assertEq(usdcTokenVault.balanceOf(BOB), 500e6);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 500e6, 0);
    usdcTokenVault.withdraw(500e6);
    assertEq(usdcTokenVault.balanceOf(BOB), 0);
    vm.stopPrank();

    vm.startPrank(ALICE);
    // Alice try to withdraw, she should be able to withdraw all staking tokens
    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), aliceLPBalance);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(ALICE, aliceLPBalance, 0);
    usdtEthSushiLpVault.withdraw(aliceLPBalance);
    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), 0);
    vm.stopPrank();

    // Neither Alice nor BOB could claim ETH since it's ETH POS, no migration happens here
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    curve3PoolLpVault.claimETH();
    vm.prank(BOB);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    curve3PoolLpVault.claimETH();
    vm.prank(ALICE);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    curveTriCrypto2LpVault.claimETH();
    vm.prank(BOB);
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotYetMigrated()"));
    curveTriCrypto2LpVault.claimETH();

    // Still, they will be able to withdraw all their staked tokens

    // Alice try to withdraw, she should be able to withdraw all staking tokens
    vm.startPrank(ALICE);
    assertEq(curve3PoolLpVault.balanceOf(ALICE), 25 ether);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(ALICE, 25 ether, 0);
    curve3PoolLpVault.withdraw(25 ether);
    assertEq(curve3PoolLpVault.balanceOf(ALICE), 0);

    assertEq(curveTriCrypto2LpVault.balanceOf(ALICE), 75 ether);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(ALICE, 75 ether, 0);
    curveTriCrypto2LpVault.withdraw(75 ether);
    assertEq(curveTriCrypto2LpVault.balanceOf(ALICE), 0);
    vm.stopPrank();

    // BOB try to withdraw, he should be able to withdraw all staking tokens
    vm.startPrank(BOB);
    assertEq(curve3PoolLpVault.balanceOf(BOB), 75 ether);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 75 ether, 0);
    curve3PoolLpVault.withdraw(75 ether);
    assertEq(curve3PoolLpVault.balanceOf(BOB), 0);

    assertEq(curveTriCrypto2LpVault.balanceOf(BOB), 25 ether);
    vm.expectEmit(true, true, true, true);
    emit Withdrawn(BOB, 25 ether, 0);
    curveTriCrypto2LpVault.withdraw(25 ether);
    assertEq(curveTriCrypto2LpVault.balanceOf(BOB), 0);
    vm.stopPrank();

    // if chainID equals to 1, owner can call migrate to split the LP to prevent some loss.
    // Migrate GovLP Vault
    vm.expectEmit(true, true, true, true);
    emit Execute(150 ether, 150 ether);
    vm.expectEmit(true, true, true, true);
    emit Migrate(150 ether, 150 ether, 150 ether);
    govLPVault.migrate();

    assertEq(govLPVault.ethSupply(), address(govLPVault).balance);
    assertEq(address(govLPVault).balance, 150 ether);
    assertEq(govLPVault.powaaSupply(), 150 ether);

    // even with chainID equals to 1, Cat and Eve should be able to claim ETH POWAA back to prevent some loss
    // Cat claims her ETH, since Cat owns 66.666% of the supply,
    // Cat would receive 100 * 150 / 150 =~ 100 ETH
    // Cat would receive 100 * 150 / 150 =~ 100 POWAA
    // After a certain amount of time (7 days ~=  604800 sec)
    // 604800 * 10 POWWA = 6048000 total POWWA to be distributed
    // 6048000 POWAA / 150 LP = 40320 POWAA per 1 LP
    // Cat own 100 LP hence, 40320 * 100 = 4032000 POWAA + 100 POWAA from LP removal = 4032100 POWAA
    vm.startPrank(CAT);
    // CAT doesn't have 0 ether, need to reset her for good
    vm.deal(CAT, 0);
    vm.expectEmit(true, true, true, true);
    emit RewardPaid(CAT, 4032000 ether);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(CAT, 100 ether, 100 ether);

    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(CAT), 0);
    assertEq(CAT.balance, 100 ether);
    assertEq(POWAAToken.balanceOf(CAT), 4032100 ether);

    // Cat try to withdraw, shouldn't be able to do so
    vm.expectRevert(abi.encodeWithSignature("TokenVault_AlreadyMigrated()"));
    govLPVault.withdraw(100e6);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(CAT.balance, 100 ether);
    assertEq(POWAAToken.balanceOf(CAT), 4032100 ether);
    vm.stopPrank();

    // Eve claims her ETH, since Eve owns 33.333% of the supply,
    // Eve would receive 50 * 150 / 150 =~ 50 ETH
    // Eve would receive 50 * 150 / 150 =~ 50 POWAA
    vm.startPrank(EVE);
    // EVE doesn't have 0 ether, need to reset her for good
    vm.deal(EVE, 0);
    vm.expectEmit(true, true, true, true);
    emit RewardPaid(EVE, 2016000 ether);
    vm.expectEmit(true, true, true, true);
    emit ClaimETHPOWAA(EVE, 50 ether, 50 ether);

    // After a certain amount of time (7 days ~=  604800 sec)
    // 604800 * 10 POWWA = 6048000 total POWWA to be distributed
    // 6048000 POWAA / 150 LP = 40320 POWAA per 1 LP
    // Eve own 50 LP hence, 40320 * 50 = 2016000 POWAA + 50 POWAA from LP removal = 2016050 POWAA
    govLPVault.claimETHPOWAA();

    assertEq(govLPVault.balanceOf(EVE), 0);
    assertEq(EVE.balance, 50 ether);
    assertEq(POWAAToken.balanceOf(EVE), 2016050 ether);

    // Cat try to claims her ETH again, shouldn't be able to do so
    govLPVault.claimETHPOWAA();
    assertEq(EVE.balance, 50 ether);
    assertEq(POWAAToken.balanceOf(EVE), 2016050 ether);
    vm.stopPrank();
  }

  function testGetApproximatedTotalExecutionRewards_WithHappyCase() external {
    // *** Alice and Bob are going to participate in USDC tokenvault
    // *** while Cat and Eve, instead, will participate in GOVLp tokenvault

    // Alice Stakes 1000 USDC to the contract
    vm.startPrank(ALICE);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 1000e6);

    usdcTokenVault.stake(1000e6);
    assertEq(usdcTokenVault.balanceOf(ALICE), 1000e6);
    vm.stopPrank();

    // Bob Stakes 1000 USDC to the contract
    vm.startPrank(BOB);
    USDC.approve(address(usdcTokenVault), 1000e6);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 1000e6);

    usdcTokenVault.stake(1000e6);

    assertEq(usdcTokenVault.balanceOf(BOB), 1000e6);
    vm.stopPrank();

    // Bob and Alice have 0.000026239198060538e18 USDT-ETH Sushi LP
    uint256 aliceLPBalance = USDT_ETH_SUSHI_LP.balanceOf(ALICE);
    uint256 bobLPBalance = USDT_ETH_SUSHI_LP.balanceOf(BOB);

    // Alice Stakes her total USDT-ETH lp balance to the contract
    vm.startPrank(ALICE);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), aliceLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, aliceLPBalance);

    usdtEthSushiLpVault.stake(aliceLPBalance);
    assertEq(usdtEthSushiLpVault.balanceOf(ALICE), aliceLPBalance);
    vm.stopPrank();

    // Bob Stakes his USDT-ETH LP Balance to the contract
    vm.startPrank(BOB);
    USDT_ETH_SUSHI_LP.approve(address(usdtEthSushiLpVault), bobLPBalance);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, bobLPBalance);

    usdtEthSushiLpVault.stake(bobLPBalance);

    assertEq(usdtEthSushiLpVault.balanceOf(BOB), bobLPBalance);
    vm.stopPrank();

    // ALICE & BOB ALSO STAKE IN CURVES POOL
    vm.startPrank(ALICE);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 25 ether);
    CURVE_3POOL_LP.approve(address(curve3PoolLpVault), 25 ether);
    curve3PoolLpVault.stake(25 ether);

    assertEq(curve3PoolLpVault.balanceOf(ALICE), 25 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(ALICE, 75 ether);
    CURVE_TRICRYPTO2_LP.approve(address(curveTriCrypto2LpVault), 75 ether);
    curveTriCrypto2LpVault.stake(75 ether);

    assertEq(curveTriCrypto2LpVault.balanceOf(ALICE), 75 ether);

    vm.stopPrank();

    vm.startPrank(BOB);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 75 ether);
    CURVE_3POOL_LP.approve(address(curve3PoolLpVault), 75 ether);
    curve3PoolLpVault.stake(75 ether);

    assertEq(curve3PoolLpVault.balanceOf(BOB), 75 ether);

    vm.expectEmit(true, true, true, true);
    emit Staked(BOB, 25 ether);
    CURVE_TRICRYPTO2_LP.approve(address(curveTriCrypto2LpVault), 25 ether);
    curveTriCrypto2LpVault.stake(25 ether);

    assertEq(curveTriCrypto2LpVault.balanceOf(BOB), 25 ether);

    vm.stopPrank();

    assertEq(100 ether, curve3PoolLpVault.totalSupply());
    assertEq(100 ether, curveTriCrypto2LpVault.totalSupply());

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

    uint256 periodFinish = usdcTokenVault.periodFinish();
    uint256 campaignEndBlock = usdcTokenVault.campaignEndBlock();

    // Warp to the end of the campaign
    // Now, chainId has been chagned to ETH POW MAINNET, let's migrate the token so we get all ETH POW
    vm.roll(campaignEndBlock);
    vm.warp(periodFinish);
    vm.chainId(POW_ETH_MAINNET);

    // [NOTE] these are estimated value from Uniswap's Quoter
    //  ~1.149546045420765471 (USDC vault)
    //  ~3.993968465987645753 (usdtEthSushi LP vault)
    //  ~0.058728319655362838 (3Pool Curve LP vault)
    // ~60.764013365169022941 (TriCrypto Curve LP vault)
    // totalEstimatedEth ~= 65.966256196232797003
    uint256 totalEstimatedEth = controller.getTotalAmountOut();
    assertEq(totalEstimatedEth, 65.966256196232797003 ether);

    // 2% of the reward will be paid to the executor
    // 2% of 65.966256196232797003 ~= 1.319325123924655938
    uint256 approximatedExecutionReward = controller
      .getApproximatedTotalExecutionRewards();
    assertEq(approximatedExecutionReward, 1.319325123924655938 ether);

    // Executor execute the migration
    vm.deal(EXECUTOR, 10 ether);
    uint256 executerEthBalanceBefore = EXECUTOR.balance;
    vm.prank(EXECUTOR);
    controller.migrate();

    uint256 executerEthBalanceAfter = EXECUTOR.balance;

    uint256 actualExecutionReward = executerEthBalanceAfter -
      executerEthBalanceBefore;

    uint256 acceptablePercentage = 0.005 ether; // 0.5%
    uint256 acceptableDelta = acceptablePercentage.mulWadDown(
      approximatedExecutionReward
    );

    assertApproxEqAbs(
      approximatedExecutionReward,
      actualExecutionReward,
      acceptableDelta
    );
  }

  /// @dev Fallback function to accept ETH.
  receive() external payable {}
}
