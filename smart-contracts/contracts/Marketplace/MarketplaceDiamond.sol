// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35; 

import { SolidstateDiamondProxy } from "@solidstate/contracts/proxy/diamond/SolidstateDiamondProxy.sol";
import { AccessControlAppStorageEnumerableMarket } from "./AppStorage.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _Context } from "@solidstate/contracts/meta/_Context.sol";
import { _Ownable } from "@solidstate/contracts/access/ownable/_Ownable.sol";

contract MarketplaceDiamond is SolidstateDiamondProxy, AccessControlAppStorageEnumerableMarket, _Ownable {
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    constructor() {
        _setOwner(msg.sender);
        s.decimals = 3;
        s.decimalPow = 10**3;
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