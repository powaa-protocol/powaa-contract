// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Factory.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IQuoter.sol";
import "../../../../contracts/v0.8.16/Controller.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";
import "../../../../contracts/v0.8.16/GovLPVault.sol";
import "../../../../contracts/v0.8.16/Timelock.sol";
import "../../../../contracts/v0.8.16/fee-model/LinearFeeModel.sol";
import "../../../../contracts/v0.8.16/migrators/gov-lp-vaults/UniswapV2GovLPVaultMigrator.sol";
import "../../../../contracts/v0.8.16/migrators/token-vaults/UniswapV3TokenVaultMigrator.sol";
import "../../../../contracts/v0.8.16/migrators/token-vaults/SushiSwapLPVaultMigrator.sol";
import "../_base/BaseTest.sol";

/// @title An abstraction of the The merge migration scenario Testing contract, containing a scaffolding method for creating the fixture
abstract contract TheMergeMigrationSingleTokenBase is BaseTest {
  using Strings for uint256;

  address public constant TREASURY = address(115);
  address public constant WITHDRAWAL_TREASURY = address(116);
  address public constant EXECUTOR = address(117);
  uint256 public constant WITHDRAWAL_TREASURY_FEE_RATE = 0.5 ether;
  uint256 public constant THE_MERGE_BLOCK = 15500000; // Assume that the merge block takes place in this block number
  uint24 public constant USDC_ETH_V3_FEE = 3000;

  // UniswapV3TokenVaultMigrator Params
  uint256 public constant TREASURY_FEE_RATE = 0.05 ether; // 5%
  uint256 public constant GOV_LP_VAULT_FEE_RATE = 0.05 ether; // 5%
  uint256 public constant CONTROLLER_FEE_RATE = 0.02 ether; // 2%

  // LinearFeeModel Params
  uint256 public constant BASE_RATE = 0;
  uint256 public constant MULTIPLIER_RATE = 0.02 ether; // 2% at 100% utilization

  // GovLPToken Params
  uint256 public constant POWAA_ETH_LIQUIDITY = 100000 ether;

  IUniswapV2Factory public uniswapV2Factory;
  IUniswapV3Factory public uniswapV3Factory;
  IUniswapV3Pool public uniswapV3USDCETHPool;

  /* ========== Migrators ========== */
  IV3SwapRouter public uniswapV3Router02;
  IUniswapV2Router02 public uniswapV2Router02;

  IQuoter public uniswapV3Quoter;

  IMigrator public govLPVaultMigrator;
  IMigrator public govLPVaultReserveMigrator;
  IMigrator public tokenVaultMigrator;
  IMigrator public tokenVaultReserveMigrator;

  /* ========== Fee Model ========== */
  IFeeModel public linearFeeModel;

  /* ========== Controller ========== */
  Controller public controller;

  /* ========== TokenVault ========== */
  TokenVault public usdcTokenVault;
  GovLPVault public govLPVault;

  /* ========== Timelock ========== */
  Timelock public timelock;

  /* ========== POWAA-ETH Uniswap V2 token ========== */
  ERC20 public powaaETHUniswapV2LP;

  constructor() {
    proxyAdmin = _setupProxyAdmin();
    mathMock = _setupMathMock();
  }

  /// @dev Foundry's setUp method
  function setUp() public virtual override {
    super.setUp();
    // Setup wrap addresses to entities
    uniswapV3Router02 = IV3SwapRouter(UNISWAP_V3_SWAP_ROUTER_02);
    uniswapV2Router02 = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);

    uniswapV3Quoter = IQuoter(UNISWAP_V3_QUOTER);

    uniswapV2Factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    uniswapV3Factory = IUniswapV3Factory(UNISWAP_V3_FACTORY_ADDRESS);
    uniswapV3USDCETHPool = IUniswapV3Pool(
      uniswapV3Factory.getPool(address(USDC), address(WETH9), USDC_ETH_V3_FEE)
    );

    // Setup FeeModel
    linearFeeModel = _setupLinearFeeModel(BASE_RATE, MULTIPLIER_RATE);
    // Setup Controller
    controller = _setupController();

    // Setup Timelock
    timelock = new Timelock(address(this), 6 hours);

    // Setup TokenVault Implementation Contract
    TokenVault tokenVaultImpl = _setupTokenVaultImpl();
    // Setup GovLPVault Implementation Contract
    GovLPVault govLPVaultImpl = _setupGovLPVaultImpl();

    // Setup POWAA-ETH Uniswap V2 token
    // current liquidity = sqrt(100000e18 * 100000e18) - 10**3 = 99999999999999999999000 ~~99999.999999999999999 LP
    address[] memory addresses = new address[](1);
    addresses[0] = address(this);
    powaaETHUniswapV2LP = _setupGovLPToken(
      addresses,
      POWAA_ETH_LIQUIDITY,
      POWAA_ETH_LIQUIDITY
    );

    //  - Create GovLPVault's Clone
    controller.deployDeterministicVault(
      address(govLPVaultImpl),
      address(this),
      address(POWAAToken),
      address(powaaETHUniswapV2LP)
    );
    // Setup GovLP related Vault and Migrator
    govLPVaultMigrator = _setupUniswapV2GovLPVaultMigrator(
      uniswapV2Router02,
      uniswapV3Quoter
    );
    govLPVault = GovLPVault(
      payable(
        controller.getDeterministicVault(
          address(govLPVaultImpl),
          address(powaaETHUniswapV2LP)
        )
      )
    );

    assertEq(govLPVault.getMasterContractOwner(), address(this));
    // Storage of a cloned instance should be correctly updated
    assertEq(address(govLPVault.masterContract()), address(govLPVaultImpl));
    assertEq(govLPVault.owner(), address(0));
    assertEq(govLPVault.rewardsDistribution(), address(this));
    assertEq(govLPVault.rewardsToken(), address(POWAAToken));
    assertEq(address(govLPVault.stakingToken()), address(powaaETHUniswapV2LP));
    assertEq(govLPVault.controller(), address(controller));
    assertEq(govLPVault.isGovLpVault(), true);

    //  - Set Migration Option for govLPVault
    govLPVault.setMigrationOption(govLPVaultMigrator);

    assertEq(address(govLPVault.migrator()), address(govLPVaultMigrator));

    //  - Whitelist the vault in the migrators
    govLPVaultMigrator.whitelistTokenVault(address(govLPVault), true);
    //  - Start a reward distribution process
    POWAAToken.transfer(address(govLPVault), 6048000 ether); // 10 POWAA / sec
    govLPVault.notifyRewardAmount(6048000 ether);
    // Setup USDCToken related Vault and Migrator
    tokenVaultMigrator = _setupUniswapV3TokenVaultMigrator(
      uniswapV3Router02,
      uniswapV3Quoter,
      address(govLPVault),
      GOV_LP_VAULT_FEE_RATE,
      TREASURY_FEE_RATE,
      address(controller),
      CONTROLLER_FEE_RATE
    );
    tokenVaultReserveMigrator = _setupUniswapV3TokenVaultMigrator(
      uniswapV3Router02,
      uniswapV3Quoter,
      address(govLPVault),
      0,
      0,
      address(controller),
      0
    );
    //  - Create TokenVault's Clone
    controller.deployDeterministicVault(
      address(tokenVaultImpl),
      address(this),
      address(POWAAToken),
      address(USDC)
    );
    usdcTokenVault = TokenVault(
      payable(
        controller.getDeterministicVault(address(tokenVaultImpl), address(USDC))
      )
    );

    assertEq(usdcTokenVault.getMasterContractOwner(), address(this));
    assertEq(address(usdcTokenVault.masterContract()), address(tokenVaultImpl));
    assertEq(usdcTokenVault.owner(), address(0));
    assertEq(usdcTokenVault.rewardsDistribution(), address(this));
    assertEq(usdcTokenVault.rewardsToken(), address(POWAAToken));
    assertEq(address(usdcTokenVault.stakingToken()), address(USDC));
    assertEq(usdcTokenVault.controller(), address(controller));
    assertEq(usdcTokenVault.isGovLpVault(), false);

    //  - Set Migration Option for usdcTokenVault
    usdcTokenVault.setMigrationOption(
      tokenVaultMigrator,
      tokenVaultReserveMigrator,
      THE_MERGE_BLOCK,
      address(linearFeeModel),
      USDC_ETH_V3_FEE,
      WITHDRAWAL_TREASURY,
      WITHDRAWAL_TREASURY_FEE_RATE
    );

    assertEq(address(usdcTokenVault.migrator()), address(tokenVaultMigrator));
    assertEq(
      address(usdcTokenVault.reserveMigrator()),
      address(tokenVaultReserveMigrator)
    );
    assertEq(
      address(usdcTokenVault.withdrawalFeeModel()),
      address(linearFeeModel)
    );
    assertEq(usdcTokenVault.feePool(), USDC_ETH_V3_FEE);
    assertEq(usdcTokenVault.treasury(), WITHDRAWAL_TREASURY);
    assertEq(usdcTokenVault.treasuryFeeRate(), WITHDRAWAL_TREASURY_FEE_RATE);
    assertEq(usdcTokenVault.campaignEndBlock(), THE_MERGE_BLOCK);

    //  - Whitelist the vault in the migrators
    tokenVaultMigrator.whitelistTokenVault(address(usdcTokenVault), true);
    tokenVaultReserveMigrator.whitelistTokenVault(
      address(usdcTokenVault),
      true
    );

    address[] memory list = new address[](1);
    list[0] = FRANK;

    _distributeUSDC(list, 1000e6);
    // Try stake/withdraw when fee rate is 0
    vm.startPrank(FRANK);
    uint256 balanceBeforeStake = USDC.balanceOf(FRANK);
    USDC.approve(address(usdcTokenVault), 1000e6);

    usdcTokenVault.stake(1000e6);
    uint256 balanceAfterStake = USDC.balanceOf(FRANK);

    assertEq(balanceBeforeStake - balanceAfterStake, 1000e6);
    assertEq(usdcTokenVault.balanceOf(FRANK), 1000e6);

    usdcTokenVault.withdraw(1000e6);

    assertEq(usdcTokenVault.balanceOf(FRANK), 0);
    assertEq(USDC.balanceOf(FRANK) - balanceAfterStake, 1000e6);

    vm.stopPrank();

    assertEq(USDC.balanceOf(FRANK), 1000e6);

    //  - Start a reward distribution process
    POWAAToken.transfer(address(usdcTokenVault), 6048000 ether); // 10 POWAA / sec
    usdcTokenVault.notifyRewardAmount(6048000 ether);

    bytes memory data = abi.encode(
      tokenVaultMigrator,
      tokenVaultReserveMigrator,
      THE_MERGE_BLOCK + 1000,
      address(linearFeeModel),
      USDC_ETH_V3_FEE,
      WITHDRAWAL_TREASURY,
      WITHDRAWAL_TREASURY_FEE_RATE
    );

    uint256 eta = block.timestamp + 6 hours;

    tokenVaultImpl.transferOwnership(address(timelock));
    assertEq(usdcTokenVault.getMasterContractOwner(), address(timelock));

    vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
    // this transaction is bound by time, at least 6 hours waiting time is needed
    vm.prank(FRANK);
    timelock.queueTransaction(
      address(usdcTokenVault),
      0,
      "setMigrationOption(address,address,uint256,address,uint24,address,uint256)",
      data,
      eta
    );

    //  - Set Migration Option for usdcTokenVault
    timelock.queueTransaction(
      address(usdcTokenVault),
      0,
      "setMigrationOption(address,address,uint256,address,uint24,address,uint256)",
      data,
      eta
    );

    // Change should not effect the state yet
    assertEq(THE_MERGE_BLOCK, usdcTokenVault.campaignEndBlock());

    vm.expectRevert(
      "Timelock::executeTransaction: Transaction hasn't surpassed time lock."
    );
    // this transaction is bound by time, at least 6 hours waiting time is needed
    timelock.executeTransaction(
      address(usdcTokenVault),
      0,
      "setMigrationOption(address,address,uint256,address,uint24,address,uint256)",
      data,
      eta
    );
    // Change should not effect the state yet
    assertEq(THE_MERGE_BLOCK, usdcTokenVault.campaignEndBlock());

    vm.expectRevert("Timelock::executeTransaction: Call must come from admin.");
    // this transaction is bound by time, at least 6 hours waiting time is needed
    vm.prank(FRANK);
    timelock.executeTransaction(
      address(usdcTokenVault),
      0,
      "setMigrationOption(address,address,uint256,address,uint24,address,uint256)",
      data,
      eta
    );
    // Change should not effect the state yet
    assertEq(THE_MERGE_BLOCK, usdcTokenVault.campaignEndBlock());

    vm.warp(block.timestamp + 7 hours);
    timelock.executeTransaction(
      address(usdcTokenVault),
      0,
      "setMigrationOption(address,address,uint256,address,uint24,address,uint256)",
      data,
      eta
    );
    assertEq(THE_MERGE_BLOCK + 1000, usdcTokenVault.campaignEndBlock());

    vm.warp(block.timestamp - 7 hours);
    // Since Timelock contract is now the owner, the former owner is now restricted from calling admin functions
    vm.expectRevert(abi.encodeWithSignature("TokenVault_NotOwner()"));
    usdcTokenVault.setMigrationOption(
      tokenVaultMigrator,
      tokenVaultReserveMigrator,
      THE_MERGE_BLOCK,
      address(linearFeeModel),
      USDC_ETH_V3_FEE,
      WITHDRAWAL_TREASURY,
      WITHDRAWAL_TREASURY_FEE_RATE
    );

    vm.prank(address(timelock));
    tokenVaultImpl.transferOwnership(address(this));

    usdcTokenVault.setMigrationOption(
      tokenVaultMigrator,
      tokenVaultReserveMigrator,
      THE_MERGE_BLOCK,
      address(linearFeeModel),
      USDC_ETH_V3_FEE,
      WITHDRAWAL_TREASURY,
      WITHDRAWAL_TREASURY_FEE_RATE
    );

    assertEq(THE_MERGE_BLOCK, usdcTokenVault.campaignEndBlock());
  }

  function _distributeUSDC(address[] memory addresses, uint256 _amount)
    internal
  {
    vm.startPrank(USDC_PHILANTHROPIST);
    for (uint256 i = 0; i < addresses.length; i++) {
      USDC.transfer(addresses[i], _amount);
    }
    vm.stopPrank();
  }

  function _setupUniswapV2GovLPVaultMigrator(
    IUniswapV2Router02 _router,
    IQuoter _quoter
  ) internal returns (UniswapV2GovLPVaultMigrator) {
    return new UniswapV2GovLPVaultMigrator(_router, _quoter);
  }

  function _setupUniswapV3TokenVaultMigrator(
    IV3SwapRouter _router,
    IQuoter _quoter,
    address _govLPVault,
    uint256 _govLPVaultFeeRate,
    uint256 _treasuryFeeRate,
    address _controller,
    uint256 _controllerFeeRate
  ) internal returns (UniswapV3TokenVaultMigrator) {
    return
      new UniswapV3TokenVaultMigrator(
        TREASURY,
        _controller,
        _govLPVault,
        _treasuryFeeRate,
        _controllerFeeRate,
        _govLPVaultFeeRate,
        _router,
        _quoter
      );
  }

  function _setupLinearFeeModel(uint256 _baseRate, uint256 _multiplierRate)
    internal
    returns (LinearFeeModel)
  {
    return new LinearFeeModel(_baseRate, _multiplierRate);
  }

  function _setupController() internal returns (Controller) {
    return new Controller();
  }

  function _setupGovLPToken(
    address[] memory _recipients,
    uint256 _powaaSupply,
    uint256 _ethSupply
  ) internal returns (ERC20) {
    for (uint256 i = 0; i < _recipients.length; i++) {
      // Increase ETH supply to the owner, so that LP can be created
      vm.deal(address(this), _ethSupply);
      // Approve router to seize some POWAA from the owner, so that LP can be created
      POWAAToken.approve(address(uniswapV2Router02), _powaaSupply);
      // Add Liquidity + Create LP
      uniswapV2Router02.addLiquidityETH{ value: _ethSupply }(
        address(POWAAToken),
        _powaaSupply,
        0,
        0,
        _recipients[i],
        block.timestamp
      );
    }
    return ERC20(uniswapV2Factory.getPair(address(POWAAToken), address(WETH9)));
  }

  function _setupTokenVaultImpl() internal returns (TokenVault) {
    return new TokenVault();
  }

  function _setupGovLPVaultImpl() internal returns (GovLPVault) {
    return new GovLPVault();
  }
}
