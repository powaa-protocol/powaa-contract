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
    IERC20[4] memory stethLPUnderlyings;
    stethLPUnderlyings[0] = IERC20(WETH9);
    stethLPUnderlyings[1] = IERC20(
      address(_setupFakeERC20("Lido Staked ETH", "stETH"))
    );

    fakeStethLpToken = new MockCurveLpToken(stethLPUnderlyings);

    fakeCurveStethStableSwap = new MockCurveFiStableSwap2();
    fakeCurve3PoolStableSwap = new MockCurveFiStableSwap();
    fakeCurveTriCrypto2StableSwap = new MockCurveFiStableSwap();

    fakeUniswapRouter = new MockV3SwapRouter();

    migrator = _setupMigrator(0.1 ether, 0.1 ether);

    mockBaseToken = _setupFakeERC20("BASE ERC20 TOKEN", "BT");
    mockLpToken = new MockETHLpToken(IERC20(address(mockBaseToken)));
    mockLpToken.initialize("BT-WETH LP", "BWELP");

    fakeUniswapRouter.mockSetSwapRate(address(mockBaseToken), 1 ether);

    migrator.mapTokenVaultRouter(
      tokenVaultSteth,
      address(fakeCurveStethStableSwap),
      2
    );
    migrator.mapTokenVaultRouter(
      tokenVault3Pool,
      address(fakeCurve3PoolStableSwap),
      3
    );
    migrator.mapTokenVaultRouter(
      tokenVaultTriCrypto2,
      address(fakeCurveTriCrypto2StableSwap),
      3
    );
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
