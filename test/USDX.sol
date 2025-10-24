pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDX is ERC20 {
    constructor() ERC20("USDX", "USDX") {
        _mint(msg.sender, 1 * 10**18);
    }
}
