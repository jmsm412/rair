// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35; 

import { SolidstateDiamondProxy } from "@solidstate/contracts/proxy/diamond/SolidstateDiamondProxy.sol";
import { AccessControlEnumerable } from "../common/DiamondStorage/AccessControlEnumerable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _Context } from "@solidstate/contracts/meta/_Context.sol";
import { _Ownable } from "@solidstate/contracts/access/ownable/_Ownable.sol";

contract FacetSource is SolidstateDiamondProxy, AccessControlEnumerable, _Ownable {
    constructor() {
        _setOwner(msg.sender);
    }

    function _msgSender() internal view virtual override(Context, _Context) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(Context, _Context) returns (bytes calldata) {
        return msg.data;
    }
}