// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35; 

contract ReceiveEthAttacker {
    receive() external payable {
        revert("Unexpected Revert Attack!");
    }
}