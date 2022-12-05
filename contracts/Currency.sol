// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Currency is ERC20 {

    // Decimals are set to 18 by default in `ERC20`
    constructor() ERC20("Currency", "USD") {
        _mint(msg.sender, 10000 ether);
    }
}