// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

abstract contract FactoryHandlerRoles {
    bytes32 public constant ADMINISTRATOR = keccak256("rair.factory.administrator");
    bytes32 public constant WITHDRAW_SIGNER = keccak256("rair.factory.withdraw_signer");
}