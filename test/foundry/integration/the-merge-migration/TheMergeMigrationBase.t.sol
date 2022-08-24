// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Factory.sol";
import "../../../../contracts/v0.8.16/Controller.sol";
import "../../../../contracts/v0.8.16/TokenVault.sol";
import "../../../../contracts/v0.8.16/fee-model/LinearFeeModel.sol";
import "../../../../contracts/v0.8.16/migrators/gov-lp-vaults/UniswapV2GovLPVaultMigrator.sol";
import "../../../../contracts/v0.8.16/migrators/token-vaults/UniswapV3TokenVaultMigrator.sol";
import "../_base/BaseTest.sol";

/// @title An abstraction of the The merge migration scenario Testing contract, containing a scaffolding method for creating the fixture
abstract contract TheMergeMigrationBase is BaseTest {
  using Strings for uint256;

  address public constant TREASURY = address(115);
  uint256 public constant THE_MERGE_BLOCK = 15500000;
  uint24 public constant USDC_ETH_V3_FEE = 3000;

  // UniswapV3TokenVaultMigrator Params
  uint256 public constant TREASURY_FEE_RATE = 0.05 ether; // 5%
  uint256 public constant GOV_LP_VAULT_FEE_RATE = 0.05 ether; // 5%

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
  TokenVault public govLPVault;

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
    uniswapV2Factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    uniswapV3Factory = IUniswapV3Factory(UNISWAP_V3_FACTORY_ADDRESS);
    uniswapV3USDCETHPool = IUniswapV3Pool(
      uniswapV3Factory.getPool(address(USDC), address(WETH9), USDC_ETH_V3_FEE)
    );

    // Setup FeeModel
    linearFeeModel = _setupLinearFeeModel(BASE_RATE, MULTIPLIER_RATE);
    // Setup Controller
    controller = _setupController();

    // Setup TokenVault Implementation Contract
    TokenVault tokenVaultImpl = _setupTokenVaultImpl();

    // Setup POWAA-ETH Uniswap V2 token
    // current liquidity = sqrt(100000e18 * 100000e18) - 10**3 = 99999999999999999999000 ~~99999.999999999999999 LP
    address[] memory addresses = new address[](1);
    addresses[0] = address(this);
    powaaETHUniswapV2LP = _setupGovLPToken(
      addresses,
      POWAA_ETH_LIQUIDITY,
      POWAA_ETH_LIQUIDITY
    );

    //  - Create TokenVault's Clone
    controller.deployDeterministicVault(
      address(tokenVaultImpl),
      address(this),
      address(POWAAToken),
      address(powaaETHUniswapV2LP),
      address(linearFeeModel),
      true
    );

    // Setup GovLP related Vault and Migrator
    govLPVaultMigrator = _setupUniswapV2GovLPVaultMigrator(uniswapV2Router02);
    govLPVaultReserveMigrator = _setupUniswapV2GovLPVaultMigrator(
      uniswapV2Router02
    );
    govLPVault = TokenVault(
      payable(
        controller.getDeterministicVault(
          address(tokenVaultImpl),
          address(powaaETHUniswapV2LP)
        )
      )
    );
    //  - Set Migration Option for govLPVault
    govLPVault.setMigrationOption(
      govLPVaultMigrator,
      govLPVaultReserveMigrator,
      THE_MERGE_BLOCK,
      0 // v2 doesn't have a fee
    );
    //  - Whitelist the vault in the migrators
    govLPVaultMigrator.whitelistTokenVault(address(govLPVault), true);
    govLPVaultReserveMigrator.whitelistTokenVault(address(govLPVault), true);
    //  - Start a reward distribution process
    POWAAToken.transfer(address(govLPVault), 6048000 ether); // 10 POWAA / sec
    govLPVault.notifyRewardAmount(6048000 ether);

    // Setup USDCToken related Vault and Migrator
    tokenVaultMigrator = _setupUniswapV3TokenVaultMigrator(
      uniswapV3Router02,
      address(govLPVault),
      GOV_LP_VAULT_FEE_RATE,
      TREASURY_FEE_RATE
    );
    tokenVaultReserveMigrator = _setupUniswapV3TokenVaultMigrator(
      uniswapV3Router02,
      address(govLPVault),
      0,
      0
    );
    //  - Create TokenVault's Clone
    controller.deployDeterministicVault(
      address(tokenVaultImpl),
      address(this),
      address(POWAAToken),
      address(USDC),
      address(linearFeeModel),
      false
    );
    usdcTokenVault = TokenVault(
      payable(
        controller.getDeterministicVault(address(tokenVaultImpl), address(USDC))
      )
    );
    //  - Set Migration Option for usdcTokenVault
    usdcTokenVault.setMigrationOption(
      tokenVaultMigrator,
      tokenVaultReserveMigrator,
      THE_MERGE_BLOCK,
      USDC_ETH_V3_FEE
    );
    //  - Whitelist the vault in the migrators
    tokenVaultMigrator.whitelistTokenVault(address(usdcTokenVault), true);
    tokenVaultReserveMigrator.whitelistTokenVault(
      address(usdcTokenVault),
      true
    );
    //  - Start a reward distribution process
    POWAAToken.transfer(address(usdcTokenVault), 6048000 ether); // 10 POWAA / sec
    usdcTokenVault.notifyRewardAmount(6048000 ether);
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

  function _setupUniswapV2GovLPVaultMigrator(IUniswapV2Router02 _router)
    internal
    returns (UniswapV2GovLPVaultMigrator)
  {
    return new UniswapV2GovLPVaultMigrator(_router);
  }

  function _setupUniswapV3TokenVaultMigrator(
    IV3SwapRouter _router,
    address _govLPVault,
    uint256 _govLPVaultFeeRate,
    uint256 _treasuryFeeRate
  ) internal returns (UniswapV3TokenVaultMigrator) {
    return
      new UniswapV3TokenVaultMigrator(
        TREASURY,
        _govLPVault,
        _govLPVaultFeeRate,
        _treasuryFeeRate,
        _router
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
}
