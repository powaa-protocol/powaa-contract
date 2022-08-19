// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ITokenVault.sol";

contract Controller is Ownable {
  using Address for address;
  using Clones for address;

  /* ========== STATE VARIABLES ========== */
  address[] public tokenVaults;
  address public govLPVault;
  mapping(address => bool) public registeredVaults;

  /* ========== EVENTS ========== */
  event Migrate(address[] vaults);
  event SetVault(address vault, bool isGovLPVault);
  event NewVault(address instance);

  /* ========== ERRORS ========== */
  error Controller_NoVaults();
  error Controller_NoGovLPVault();

  /* ========== VIEWS ========== */

  function getDeterministicVault(address implementation, address _rewardsToken)
    public
    view
    returns (address predicted)
  {
    bytes32 salt = keccak256(abi.encodePacked(_rewardsToken));
    return implementation.predictDeterministicAddress(salt);
  }

  /* ========== ADMIN FUNCTIONS ========== */

  function _whitelistVault(address _vault, bool _isGovLPVault) private {
    if (_isGovLPVault) {
      govLPVault = _vault;
    } else {
      tokenVaults.push(_vault);
    }

    registeredVaults[_vault] = true;

    emit SetVault(_vault, _isGovLPVault);
  }

  function _initVaultAndEmit(
    address _instance,
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller,
    address _withdrawalFeeModel,
    bool _isGovLPVault
  ) private {
    ITokenVault(_instance).initialize(
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      _controller,
      _withdrawalFeeModel,
      _isGovLPVault
    );

    emit NewVault(_instance);
  }

  function deployDeterministicVault(
    address _implementation,
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _withdrawalFeeModel,
    bool _isGovLPVault
  ) external onlyOwner {
    bytes32 salt = keccak256(abi.encodePacked(_stakingToken));
    address clone = _implementation.cloneDeterministic(salt);

    _initVaultAndEmit(
      clone,
      _rewardsDistribution,
      _rewardsToken,
      _stakingToken,
      address(this),
      _withdrawalFeeModel,
      _isGovLPVault
    );

    _whitelistVault(clone, _isGovLPVault);
  }

  function migrate() external onlyOwner {
    if (tokenVaults.length == 0) revert Controller_NoVaults();
    uint256 vaultLength = tokenVaults.length;
    address[] memory _vaults = new address[](vaultLength + 1);

    for (uint256 index = 0; index < vaultLength; index++) {
      _vaults[index] = tokenVaults[index];
      ITokenVault(tokenVaults[index]).migrate();
    }

    if (govLPVault == address(0)) {
      revert Controller_NoGovLPVault();
    }

    _vaults[vaultLength] = govLPVault;
    ITokenVault(govLPVault).migrate();

    emit Migrate(_vaults);
  }
}
