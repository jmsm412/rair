// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { RAIR721Storage } from "../AppStorage.sol";
import { ERC721AccessControlRoles } from "../AccessControlRoles.sol";
import { AccessControlEnumerable } from "../../../common/DiamondStorage/AccessControlEnumerable.sol";
import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";

abstract contract RAIRRoyaltiesFacet is ERC721AccessControlRoles, AccessControlEnumerable, IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view override returns (address, uint256) {
        return (
            getRoleMember(CREATOR, 0),
            (salePrice * RAIR721Storage.layout().royaltyFee) / 100000
        );
    }

    function royaltyFee() external view returns (uint16) {
        return RAIR721Storage.layout().royaltyFee;
    }
}