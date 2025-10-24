// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Create2 {

    event Deployed(address addr);

    function deploy(bytes memory bytecode, bytes32 salt) external payable returns (address) {
        address addr;
        assembly {
            addr := create2(
                callvalue(), // Forward any Ether sent
                add(bytecode, 0x20), // Actual code starts at 0x20 (skip length prefix)
                mload(bytecode), // Bytecode length
                salt // Salt for CREATE2
            )
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
        emit Deployed(addr);
        return addr;
    }

    function computeAddress(bytes32 salt, bytes memory bytecode) public view returns (address) {
        bytes32 bytecodeHash = keccak256(bytecode);
        return address(
            uint160(uint(keccak256(abi.encodePacked(
                hex"ff",
                address(this),
                salt,
                bytecodeHash
            ))))
        );
    }

}
