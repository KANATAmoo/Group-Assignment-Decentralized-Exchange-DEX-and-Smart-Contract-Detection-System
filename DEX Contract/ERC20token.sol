// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol){
        _mint(_msgSender(), 100 ether);
    }
}