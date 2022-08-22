// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../_base/BaseTest.sol";
import "../_mock/MockERC20.sol";
import "../_mock/MockLpToken.sol";
import "mock-contract/MockContract.sol";
import "../../../../contracts/v0.8.16/interfaces/apis/IUniswapV2Router02.sol";
import "../../../../contracts/v0.8.16/migrators/gov-lp-vaults/UniswapV2GovLPVaultMigrator.sol";

/// @title An abstraction of the UniswapV2GovLPVaultMigrator Testing contract, containing a scaffolding method for creating the fixture
abstract contract UniswapV2GovLPVaultMigratorBaseTest is BaseTest {
  MockContract internal mockRouter;
  MockLpToken internal mockLp;
  MockERC20 internal mockToken0;
  MockERC20 internal mockToken1;

  UniswapV2GovLPVaultMigrator internal uniswapV2GovLPVaultMigrator;

  /// @dev Foundry's setUp method
  function setUp() public virtual {
    mockRouter = new MockContract();
    mockLp = _setupMockLpToken("RAND-MOCK-GLP", "RMGLP");
    mockToken0 = _setupFakeERC20("MockToken0", "MT0");
    mockToken1 = _setupFakeERC20("MockToken1", "MT1");

    uniswapV2GovLPVaultMigrator = _setupUniswapV2GovLPVaultMigrator(
      IUniswapV2Router02(address(mockRouter))
    );
    mockLp.givenMethodReturnAddress(
      abi.encodePacked(bytes4(keccak256("token0()"))),
      address(mockToken0)
    );
    mockLp.givenMethodReturnAddress(
      abi.encodePacked(bytes4(keccak256("token1()"))),
      address(mockToken1)
    );
  }

  function _setupUniswapV2GovLPVaultMigrator(IUniswapV2Router02 _router)
    internal
    returns (UniswapV2GovLPVaultMigrator)
  {
    UniswapV2GovLPVaultMigrator _uniswapV2GovLPVaultMigrator = new UniswapV2GovLPVaultMigrator(
        _router
      );

    return _uniswapV2GovLPVaultMigrator;
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

  function _setupMockLpToken(string memory _name, string memory _symbol)
    internal
    returns (MockLpToken)
  {
    MockLpToken _impl = new MockLpToken();
    TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
      address(_impl),
      address(proxyAdmin),
      abi.encodeWithSelector(
        bytes4(keccak256("initialize(string,string)")),
        _name,
        _symbol
      )
    );
    return MockLpToken(payable(_proxy));
  }
}
