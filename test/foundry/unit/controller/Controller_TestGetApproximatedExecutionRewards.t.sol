// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ControllerBase.t.sol";

import "../_mock/MockERC20.sol";

contract Controller_TestGetApproximatedExecutionRewards is ControllerBaseTest {
  address internal constant MOCK_REWARD_DISTRIBUTION = address(10);
  address internal constant MOCK_REWARD_TOKEN = address(11);
  address internal constant MOCK_WITHDRAWAL_FEE_MODEL = address(12);

  error Controller_NoVaults();

  /// @dev foundry's setUp method
  function setUp() public override {
    super.setUp();
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

  function _deployVault(address _stakingToken, address _impl)
    internal
    returns (address)
  {
    // Vault can be deterministically get using staking token as a salt
    address deterministicAddress = controller.getDeterministicVault(
      _impl,
      _stakingToken
    );

    controller.deployDeterministicVault(
      _impl,
      MOCK_REWARD_DISTRIBUTION,
      MOCK_REWARD_TOKEN,
      _stakingToken
    );

    return deterministicAddress;
  }

  function test_WhenNoVaultDeployed() external {
    vm.expectRevert(abi.encodeWithSignature("Controller_NoVaults()"));
    controller.getTotalAmountOut();
  }

  function test_WhenSomeVaultDeployed() external {
    MockERC20 stakingToken = _setupFakeERC20("first fake staking token", "FFS");
    MockERC20 stakingToken2 = _setupFakeERC20(
      "second fake staking token",
      "SFS"
    );
    MockERC20 stakingToken3 = _setupFakeERC20(
      "third fake staking token",
      "TFS"
    );
    address[] memory vaults = new address[](3);

    // Deploy a token vaults
    vaults[0] = _deployVault(
      address(stakingToken),
      address(mockTokenVaultImpl)
    );
    vaults[1] = _deployVault(
      address(stakingToken2),
      address(mockTokenVaultImpl)
    );
    vaults[2] = _deployVault(
      address(stakingToken3),
      address(mockTokenVaultImpl)
    );

    stakingToken.mint(vaults[0], 10 ether);
    MockTokenVault(payable(address(vaults[0]))).mockSetEthConversionRate(
      1 ether
    );
    MockTokenVault(payable(address(vaults[0]))).mockSetControllerFeeRate(
      0.4 ether
    );

    stakingToken2.mint(vaults[1], 20 ether);
    MockTokenVault(payable(address(vaults[1]))).mockSetEthConversionRate(
      1 ether
    );
    MockTokenVault(payable(address(vaults[1]))).mockSetControllerFeeRate(
      0.2 ether
    );

    stakingToken3.mint(vaults[2], 30 ether);
    MockTokenVault(payable(address(vaults[2]))).mockSetEthConversionRate(
      1 ether
    );
    MockTokenVault(payable(address(vaults[2]))).mockSetControllerFeeRate(
      0.6 ether
    );

    uint256 totalAmount = controller.getApproximatedTotalExecutionRewards();
    assertEq(26 ether, totalAmount);
  }
}
