// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { SolidstateDiamondProxy } from "@solidstate/contracts/proxy/diamond/SolidstateDiamondProxy.sol";
import { AccessControlEnumerable } from "../common/DiamondStorage/AccessControlEnumerable.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _Context } from "@solidstate/contracts/meta/_Context.sol";
import { _Ownable } from "@solidstate/contracts/access/ownable/_Ownable.sol";
import { MarketplaceStorage } from "./AppStorage.sol";

contract MarketplaceDiamond is SolidstateDiamondProxy, AccessControlEnumerable, _Ownable {
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");

    constructor() {
        _setOwner(msg.sender);
        
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        s.decimals = 3;
        s.decimalPow = 10 ** 3;
        s.nodeFee = 1 * s.decimalPow;
        s.treasuryFee = 9 * s.decimalPow;

        _setRoleAdmin(MAINTAINER, MAINTAINER);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MAINTAINER, msg.sender);
    }

    function _msgSender() internal view virtual override(Context, _Context) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(Context, _Context) returns (bytes calldata) {
        return msg.data;
    }
}