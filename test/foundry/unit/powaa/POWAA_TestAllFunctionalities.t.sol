// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./POWAABase.t.sol";

contract POWAAToken_Test is POWAABase {
  using Strings for uint256;

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
  }

  function test_Init_ERC20Meta() external {
    // assertions
    assertEq(POWAAToken.symbol(), "POWAA");
    assertEq(POWAAToken.name(), "POWAA token");
    assertEq(POWAAToken.decimals(), 18);
    assertEq(POWAAToken.totalSupply(), 0);
    assertEq(POWAAToken.maxTotalSupply(), 100 * 10**18);
  }

  function test_Mint_WhenCallerIsNotOwner() external {
    vm.prank(ALICE);

    // assertions
    vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
    POWAAToken.mint(ALICE, 1 * 10**18);
  }

  function test_Mint_WhenExceedMaxTotalSupply() external {
    address owner = address(this);
    uint256 mintAmount = 101 * 10**18;

    // assertions
    vm.expectRevert(abi.encodeWithSignature("POWAA_MaxTotalSupplyExceeded()"));
    POWAAToken.mint(owner, mintAmount);
  }

  function test_Mint() external {
    address owner = address(this);
    uint256 mintAmount = 1 * 10**18;

    // assertions
    POWAAToken.mint(owner, mintAmount);
    assertEq(POWAAToken.balanceOf(owner), mintAmount);
    assertEq(POWAAToken.totalSupply(), mintAmount);
  }

  function test_Mint_WhenMintMultipleTimes() external {
    address owner = address(this);

    // mint 10e18 #1
    uint256 mintAmount = 10 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // assertions
    assertEq(POWAAToken.balanceOf(owner), mintAmount);
    assertEq(POWAAToken.totalSupply(), mintAmount);

    // mint 10e18 #2
    POWAAToken.mint(owner, mintAmount);
    // assertions
    assertEq(POWAAToken.balanceOf(owner), mintAmount + mintAmount);
    assertEq(POWAAToken.totalSupply(), mintAmount + mintAmount);

    // mint 10e18 #3
    POWAAToken.mint(owner, mintAmount);
    // assertions
    assertEq(POWAAToken.balanceOf(owner), mintAmount + mintAmount + mintAmount);
    assertEq(POWAAToken.totalSupply(), mintAmount + mintAmount + mintAmount);
  }

  function test_Transfer_WhenNotEnoughBalance() external {
    address owner = address(this);

    // OWNER mint 100e18
    uint256 mintAmount = 100 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // transfer 101e18 to ALICE
    uint256 transferAmount = 101 * 10**18;

    // assertions
    vm.expectRevert(abi.encodePacked("ERC20: transfer amount exceeds balance"));
    POWAAToken.transfer(ALICE, transferAmount);
  }

  function test_Transfer_WhenZeroAddress() external {
    address owner = address(this);

    // OWNER mint 100e18
    uint256 mintAmount = 100 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // transfer 101e18 to address(0)
    uint256 transferAmount = 5 * 10**18;

    // assertions
    vm.expectRevert(abi.encodePacked("ERC20: transfer to the zero address"));
    POWAAToken.transfer(address(0), transferAmount);
  }

  function test_Transfer() external {
    address owner = address(this);

    // OWNER mint 100e18
    uint256 mintAmount = 100 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // transfer 5e18 to ALICE
    uint256 transferAmount = 5 * 10**18;
    POWAAToken.transfer(ALICE, transferAmount);

    // assertions
    assertEq(POWAAToken.balanceOf(owner), 95 * 10**18);
    assertEq(POWAAToken.balanceOf(owner), 95 * 10**18);
    assertEq(POWAAToken.balanceOf(ALICE), 5 * 10**18);
  }

  function test_TransferFrom_WhenNotEnoughAllowance() external {
    address owner = address(this);

    // OWNER mint 100e18
    uint256 mintAmount = 100 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // transferFrom 5e18 from OWNER to ALICE
    vm.prank(ALICE);
    uint256 transferAmount = 5 * 10**18;

    // assertions
    vm.expectRevert(abi.encodePacked("ERC20: insufficient allowance"));
    POWAAToken.transferFrom(owner, ALICE, transferAmount);
  }

  function test_TransferFrom_WhenNotEnoughBalance() external {
    address owner = address(this);

    // OWNER mint 100e18
    uint256 mintAmount = 100 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // set allowance for ALICE
    uint256 allowanceAmount = 500 * 10**18;
    POWAAToken.increaseAllowance(ALICE, allowanceAmount);
    uint256 transferAmount = 101 * 10**18;

    // assertions
    vm.expectRevert(abi.encodePacked("ERC20: transfer amount exceeds balance"));
    POWAAToken.transfer(ALICE, transferAmount);
  }

  function test_TransferFrom_Success() external {
    address owner = address(this);

    // OWNER mint 100e18
    uint256 mintAmount = 100 * 10**18;
    POWAAToken.mint(owner, mintAmount);
    // set allowance for ALICE
    uint256 allowanceAmount = 40 * 10**18;
    POWAAToken.increaseAllowance(ALICE, allowanceAmount);

    // assertions
    assertEq(POWAAToken.allowance(owner, ALICE), allowanceAmount);

    // transferFrom owner to ALICE
    vm.prank(ALICE);
    uint256 transferAmount = 30 * 10**18;
    POWAAToken.transferFrom(owner, ALICE, transferAmount);

    // assertions
    assertEq(POWAAToken.balanceOf(owner), 70 * 10**18);
    assertEq(POWAAToken.balanceOf(ALICE), 30 * 10**18);
    assertEq(
      POWAAToken.allowance(owner, ALICE),
      allowanceAmount - transferAmount
    );
  }
}
