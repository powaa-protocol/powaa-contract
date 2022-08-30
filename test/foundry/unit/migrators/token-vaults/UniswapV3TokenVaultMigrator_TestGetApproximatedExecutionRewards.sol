// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseUniswapV3TokenVaultMigratorFixture.sol";
import "../../_mock/MockWETH9.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";
import "../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

contract UniswapV3TokenVaultMigrator_TestGetApproximatedExecutionRewards is
  BaseUniswapV3TokenVaultMigratorFixture
{
  using SafeMath for uint256;
  using FixedPointMathLib for uint256;

  UniswapV3TokenVaultMigratorTestState public fixture;
  address public constant WETH9 =
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint256 public constant WETH9_NATIVE_BALANCE = 100000000 ether;

  function _setUpWithFeeParameters(
    uint256 _treasuryFeeRate,
    uint256 _controllerFeeRate,
    uint256 _govLPTokenVaultFeeRate
  ) internal {
    UniswapV3TokenVaultMigratorTestState
      memory _fixture = _scaffoldUniswapV3TokenVaultMigratorTestState(
        _treasuryFeeRate,
        _controllerFeeRate,
        _govLPTokenVaultFeeRate
      );

    fixture = UniswapV3TokenVaultMigratorTestState({
      migrator: _fixture.migrator,
      treasury: _fixture.treasury,
      controller: _fixture.controller,
      govLPTokenVault: _fixture.govLPTokenVault,
      fakeSwapRouter: _fixture.fakeSwapRouter,
      fakeTokenVault: _fixture.fakeTokenVault,
      fakeStakingToken: _fixture.fakeStakingToken,
      fakeQuoter: _fixture.fakeQuoter
    });

    vm.expectEmit(true, true, true, true);
    emit WhitelistTokenVault(address(fixture.fakeTokenVault), true);
    fixture.migrator.whitelistTokenVault(address(fixture.fakeTokenVault), true);
  }

  function setUp() public {
    _setUpWithFeeParameters(0.1 ether, 0.5 ether, 0.1 ether);

    MockWETH9 mockWETH9 = new MockWETH9();
    bytes memory wrappedETH9Code = address(mockWETH9).code;

    vm.etch(WETH9, wrappedETH9Code);
    MockWETH9(payable(WETH9)).initialize("Wrapped Ether", "WETH");

    // pre-minted token for mocking purposes
    vm.deal(WETH9, WETH9_NATIVE_BALANCE);
    MockERC20(payable(WETH9)).mint(
      address(fixture.fakeSwapRouter),
      1000000 ether
    );
  }

  function testGetApproximatedExecutionRewards_WhenControllerFeeIsSet()
    external
  {
    fixture.fakeQuoter.mockSetQuoteToNativeRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    bytes memory data = abi.encode(
      address(fixture.fakeStakingToken),
      uint24(0),
      uint256(100 ether)
    );

    uint256 controllerFee = fixture.migrator.getApproximatedExecutionRewards(
      data
    );

    // controller fee is 50% deducted from the quoted amount (100 ether, as the quotation rate is mocked)
    assertEq(50 ether, controllerFee);
  }
}
