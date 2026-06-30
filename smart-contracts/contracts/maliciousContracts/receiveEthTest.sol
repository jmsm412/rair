// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35; 

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ReceiverTest is Ownable {
    constructor() Ownable(msg.sender) {}

    function withdraw() public onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
}