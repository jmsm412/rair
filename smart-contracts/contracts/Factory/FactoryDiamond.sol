// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35; 

import { SolidstateDiamondProxy } from "@solidstate/contracts/proxy/diamond/SolidstateDiamondProxy.sol";
import { AccessControlEnumerable } from "../common/DiamondStorage/AccessControlEnumerable.sol";
import { FactoryHandlerRoles } from "./AccessControlRoles.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _Context } from "@solidstate/contracts/meta/_Context.sol";
import { _Ownable } from "@solidstate/contracts/access/ownable/_Ownable.sol";

contract FactoryDiamond is SolidstateDiamondProxy, AccessControlEnumerable, FactoryHandlerRoles, _Ownable {
    constructor() {
        _setOwner(msg.sender);
        _setRoleAdmin(ADMINISTRATOR, ADMINISTRATOR);
        _setRoleAdmin(WITHDRAW_SIGNER, ADMINISTRATOR);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMINISTRATOR, msg.sender);
        _grantRole(WITHDRAW_SIGNER, msg.sender);
    }

    function _msgSender() internal view virtual override(Context, _Context) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(Context, _Context) returns (bytes calldata) {
        return msg.data;
    }
}