// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/ITokenVault.sol";
import "forge-std/console2.sol";

contract Controller is Ownable {
  /* ========== STATE VARIABLES ========== */
  address[] public vaults;
  mapping(address => bool) public vaultsRegister;

  /* ========== EVENTS ========== */
  event Migrate(address[] vaults);
  event Vault(address vault);

  /* ========== ERRORS ========== */
  error Controller_NoVaults();

  /* ========== CONSTRUCTOR ========== */
  constructor(address _vault) {
    vaults.push(_vault);
    vaultsRegister[_vault] = false;
  }

  function setVault(address _vault) public {
    vaults.push(_vault);
    vaultsRegister[_vault] = false;

    emit Vault(_vault);
  }

  function migrate() public onlyOwner {
    if (vaults.length == 0) revert Controller_NoVaults();
    for (uint256 index = 0; index < vaults.length; index++) {
      ITokenVault(vaults[index]).migrate();
      vaultsRegister[vaults[index]] = true;
    }

    emit Migrate(vaults);
  }
}
