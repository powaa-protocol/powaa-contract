// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

import "../../../_base/BaseTest.sol";
import "../../../_mock/MockTokenVault.sol";
import "../../../_mock/MockCurveLpToken.sol";
import "../../../_mock/MockCurveFiStableSwap.sol";
import "../../../_mock/MockCurveFiStableSwap2.sol";
import "../../../_mock/MockV3SwapRouter.sol";
import "../../../_mock/MockETHLpToken.sol";
import "../../../_mock/MockWETH9.sol";
import "../../../../../../contracts/v0.8.16/migrators/token-vaults/CurveLPVaultMigrator.sol";
import "../../../../../../contracts/v0.8.16/interfaces/apis/ICurveFiStableSwap.sol";

/// @title An abstraction of the CurveLPVaultMigrator Testing contract, containing a scaffolding method for creating the fixture
abstract contract CurveLPVaultMigratorBaseTest is BaseTest {
  CurveLPVaultMigrator internal migrator;

  address internal constant tokenVaultSteth = address(77777);
  address internal constant tokenVault3Pool = address(88888);
  address internal constant tokenVaultTriCrypto2 = address(99999);

  MockCurveLpToken internal fakeStethLpToken;
  MockCurveLpToken internal fake3PoolLpToken;
  MockCurveLpToken internal fakeTriCrypto2LpToken;

  MockCurveFiStableSwap2 internal fakeCurveStethStableSwap;
  MockCurveFiStableSwap internal fakeCurve3PoolStableSwap;
  MockCurveFiStableSwap internal fakeCurveTriCrypto2StableSwap;
  MockV3SwapRouter internal fakeUniswapRouter;

  MockERC20 internal mockBaseToken;
  MockETHLpToken internal mockLpToken;

  address internal constant treasury = address(12345);
  address internal constant govLPTokenVault = address(54321);

  address public constant WETH9 =
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  event Execute(uint256 vaultReward);

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    _setupMockWETH9(100000000 ether);
    fakeUniswapRouter = new MockV3SwapRouter();

    migrator = _setupMigrator(0.1 ether, 0.1 ether);

    mockBaseToken = _setupFakeERC20("BASE ERC20 TOKEN", "BT");
    mockLpToken = new MockETHLpToken(IERC20(address(mockBaseToken)));
    mockLpToken.initialize("BT-WETH LP", "BWELP");

    fakeUniswapRouter.mockSetSwapRate(address(mockBaseToken), 1 ether);

    _setupFakeCurveStETHPoolLP();
    _setupFakeCurve3PoolLP();
    _setupFakeCurveTriCryptoLP();
  }

  function _setupFakeCurveStETHPoolLP() internal {
    MockERC20[4] memory stethLPUnderlyings;
    stethLPUnderlyings[0] = MockERC20(payable(WETH9));
    stethLPUnderlyings[1] = _setupFakeERC20("Lido Staked ETH", "stETH");

    uint256[2] memory exchangeRates;
    exchangeRates[0] = 0.5 ether;
    exchangeRates[1] = 0.5 ether;

    fakeStethLpToken = new MockCurveLpToken(stethLPUnderlyings);
    fakeCurveStethStableSwap = new MockCurveFiStableSwap2(
      fakeStethLpToken,
      exchangeRates
    );

    migrator.whitelistTokenVault(tokenVaultSteth, true);
    migrator.mapTokenVaultRouter(
      tokenVaultSteth,
      address(fakeCurveStethStableSwap),
      2
    );
  }

  function _preMintFakeCurveStETHPoolLPUnderlyings(address to, uint256 amount)
    internal
  {
    fakeStethLpToken.tokens(0).mint(to, amount);
    fakeStethLpToken.tokens(1).mint(to, amount);
  }

  function _setupFakeCurve3PoolLP() internal {
    // DAI, USDC, USDT
    MockERC20[4] memory threePoolLPUnderlyings;
    threePoolLPUnderlyings[0] = _setupFakeERC20("Fake DAI", "DAI");
    threePoolLPUnderlyings[1] = _setupFakeERC20("Fake USDC", "USDC");
    threePoolLPUnderlyings[2] = _setupFakeERC20("Fake USDT", "USDT");

    uint256[3] memory exchangeRates;
    exchangeRates[0] = 0.3 ether;
    exchangeRates[1] = 0.3 ether;
    exchangeRates[2] = 0.4 ether;

    fake3PoolLpToken = new MockCurveLpToken(threePoolLPUnderlyings);
    fakeCurve3PoolStableSwap = new MockCurveFiStableSwap(
      fake3PoolLpToken,
      exchangeRates
    );

    migrator.whitelistTokenVault(tokenVault3Pool, true);
    migrator.mapTokenVaultRouter(
      tokenVault3Pool,
      address(fakeCurve3PoolStableSwap),
      3
    );
  }

  function _preMintFakeCurve3PoolLPUnderlyings(address to, uint256 amount)
    internal
  {
    fake3PoolLpToken.tokens(0).mint(to, amount);
    fake3PoolLpToken.tokens(1).mint(to, amount);
    fake3PoolLpToken.tokens(2).mint(to, amount);
  }

  function _setupFakeCurveTriCryptoLP() internal {
    // USDT, BTC, ETH
    MockERC20[4] memory triCrypto2LPUnderlyings;
    triCrypto2LPUnderlyings[0] = _setupFakeERC20("Fake USDT", "USDT");
    triCrypto2LPUnderlyings[1] = _setupFakeERC20("Fake BTC", "BTC");
    triCrypto2LPUnderlyings[2] = _setupFakeERC20("Fake ETH", "ETH");

    uint256[3] memory exchangeRates;
    exchangeRates[0] = 0.4 ether;
    exchangeRates[1] = 0.3 ether;
    exchangeRates[2] = 0.3 ether;

    fakeTriCrypto2LpToken = new MockCurveLpToken(triCrypto2LPUnderlyings);
    fakeCurveTriCrypto2StableSwap = new MockCurveFiStableSwap(
      fakeTriCrypto2LpToken,
      exchangeRates
    );

    migrator.whitelistTokenVault(tokenVaultTriCrypto2, true);
    migrator.mapTokenVaultRouter(
      tokenVaultTriCrypto2,
      address(fakeCurveTriCrypto2StableSwap),
      3
    );
  }

  function _preMintFakeCurveTriCrypto2LPUnderlyings(address to, uint256 amount)
    internal
  {
    fakeTriCrypto2LpToken.tokens(0).mint(to, amount);
    fakeTriCrypto2LpToken.tokens(1).mint(to, amount);
    fakeTriCrypto2LpToken.tokens(2).mint(to, amount);
  }

  function _setupMigrator(
    uint256 _govLPTokenVaultFeeRate,
    uint256 _treasuryFeeRate
  ) internal returns (CurveLPVaultMigrator) {
    CurveLPVaultMigrator _migrator = new CurveLPVaultMigrator(
      treasury,
      govLPTokenVault,
      _govLPTokenVaultFeeRate,
      _treasuryFeeRate,
      IV3SwapRouter(address(fakeUniswapRouter))
    );

    return _migrator;
  }

  function _setupFakeERC20(string memory _name, string memory _symbol)
    internal
    returns (MockERC20)
  {
    MockERC20 _impl = new MockERC20();
    TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
      address(_impl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        bytes4(keccak256("initialize(string,string)")),
        _name,
        _symbol
      )
    );
    return MockERC20(payable(_proxy));
  }

  function _setupMockWETH9(uint256 initialAmount) internal {
    MockWETH9 mockWETH9 = new MockWETH9();
    bytes memory wrappedETH9Code = address(mockWETH9).code;

    vm.etch(WETH9, wrappedETH9Code);
    MockWETH9(payable(WETH9)).initialize("Wrapped Ether", "WETH");

    // pre-minted token for mocking purposes
    vm.deal(WETH9, initialAmount);
  }

  receive() external payable {}
}