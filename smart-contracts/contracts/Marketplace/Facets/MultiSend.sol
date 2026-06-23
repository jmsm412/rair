// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25; 

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title  RAIR Diamond - Multi send facet
/// @notice Tool to send multiple ERC20 tokens
contract MultiSendTool {
	function multiSendERC20(
        address erc20Address,
        address payable[] calldata recipients,
        uint[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "MultiSend: Invalid array sizes");
        IERC20 token = IERC20(erc20Address);
		for (uint i = 0; i < recipients.length; i++) {
            token.transferFrom(msg.sender, recipients[i], amounts[i]);
        }
	}

    function multiSendERC20SameAmount(
        address erc20Address,
        address payable[] calldata recipients,
        uint amount
    ) external {
        IERC20 token = IERC20(erc20Address);
		for (uint i = 0; i < recipients.length; i++) {
            token.transferFrom(msg.sender, recipients[i], amount);
        }
	}
}