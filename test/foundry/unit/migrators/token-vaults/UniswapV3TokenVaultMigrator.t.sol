// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./BaseUniswapV3TokenVaultMigratorFixture.sol";
import "../../_mock/MockWETH9.sol";
import "../../../../../contracts/v0.8.16/TokenVault.sol";

contract UniswapV3TokenVaultMigrator_Test is
  BaseUniswapV3TokenVaultMigratorFixture
{
  using SafeMath for uint256;

  UniswapV3TokenVaultMigratorTestState public fixture;
  address public constant WETH9 =
    address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  uint256 public constant WETH9_NATIVE_BALANCE = 100000000 ether;

  function setUp() public {
    UniswapV3TokenVaultMigratorTestState
      memory _fixture = _scaffoldUniswapV3TokenVaultMigratorTestState();

    fixture = UniswapV3TokenVaultMigratorTestState({
      migrator: _fixture.migrator,
      treasury: _fixture.treasury,
      govLPTokenVault: _fixture.govLPTokenVault,
      fakeSwapRouter: _fixture.fakeSwapRouter,
      fakeTokenVault: _fixture.fakeTokenVault,
      fakeStakingToken: _fixture.fakeStakingToken
    });

    vm.expectEmit(true, true, true, true);
    emit WhitelistTokenVault(address(fixture.fakeTokenVault), true);
    fixture.migrator.whitelistTokenVault(address(fixture.fakeTokenVault), true);

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

  function testExecute_whenProperlyCallWithWhitelistedAccount() external {
    fixture.fakeStakingToken.mint(address(fixture.migrator), 1000 ether);
    fixture.fakeSwapRouter.mockSetSwapRate(
      address(fixture.fakeStakingToken),
      1 ether
    );

    bytes memory data = abi.encode(
      address(fixture.fakeStakingToken),
      uint24(0)
    );

    vm.expectEmit(true, true, true, true);
    emit Execute(800 ether, 100 ether, 100 ether);

    vm.prank(address(fixture.fakeTokenVault));
    fixture.migrator.execute(data);

    // 0.1 treasury fee, 0.1 gov Vault fee
    assertEq(800 ether, address(fixture.fakeTokenVault).balance);
    assertEq(100 ether, address(fixture.treasury).balance);
    assertEq(100 ether, address(fixture.govLPTokenVault).balance);
  }

  function testExecute_whenCallWithWhitelistedAccountAndNoStakedTokenBalance()
    external
  {
    fixture.fakeStakingToken.mint(address(fixture.migrator), 0);

    bytes memory data = abi.encode(
      address(fixture.fakeStakingToken),
      uint24(0)
    );

    vm.expectEmit(true, true, true, true);
    emit Execute(0, 0, 0);

    vm.prank(address(fixture.fakeTokenVault));
    fixture.migrator.execute(data);

    // 0.1 treasury fee, 0.1 gov Vault fee
    assertEq(0, address(fixture.fakeTokenVault).balance);
    assertEq(0, address(fixture.treasury).balance);
    assertEq(0, address(fixture.govLPTokenVault).balance);
  }

  function testExecute_whenCallWithUnauthorizedAccount() external {
    vm.expectRevert(
      abi.encodeWithSignature(
        "UniswapV3TokenVaultMigrator_OnlyWhitelistedTokenVault()"
      )
    );

    bytes memory data = abi.encode(address(0), uint24(0));
    fixture.migrator.execute(data);
  }
}
