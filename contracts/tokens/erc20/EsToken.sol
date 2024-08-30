// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IMintable} from "../../interfaces/IMintable.sol";
import {Governable} from "../../core/Governable.sol";

contract EsToken is ERC20, IMintable, Governable {
  bool public inPrivateTransferMode;

  mapping(address account => bool status) public override isMinter;

  mapping(address account => bool status) public isHandler;

  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

  modifier onlyMinter() {
    require(isMinter[msg.sender], "EsToken: forbidden");
    _;
  }

  function setMinter(address _minter, bool _isActive) external override onlyGov {
    isMinter[_minter] = _isActive;
  }

  function mint(address _account, uint256 _amount) external override onlyMinter {
    _mint(_account, _amount);
  }

  function burn(address _account, uint256 _amount) external override onlyMinter {
    _burn(_account, _amount);
  }

  function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
    inPrivateTransferMode = _inPrivateTransferMode;
  }

  function setHandler(address _handler, bool _isActive) external onlyGov {
    isHandler[_handler] = _isActive;
  }

  function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
    if (isHandler[msg.sender]) {
      _transfer(_sender, _recipient, _amount);
      return true;
    }
    _spendAllowance(_sender, msg.sender, _amount);
    _transfer(_sender, _recipient, _amount);
    return true;
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    if (inPrivateTransferMode) {
      require(isHandler[msg.sender], "EsToken: msg.sender not whitelisted");
    }
    super._beforeTokenTransfer(from, to, amount);
  }
}
