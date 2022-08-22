// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "mock-contract/MockContract.sol";

contract MockLpToken is ERC20Upgradeable, OwnableUpgradeable, MockContract {
  function initialize(string memory _name, string memory _symbol)
    public
    initializer
  {
    OwnableUpgradeable.__Ownable_init();
    ERC20Upgradeable.__ERC20_init(_name, _symbol);
  }

  function mint(address _to, uint256 _amount) public onlyOwner {
    _mint(_to, _amount);
  }
}
