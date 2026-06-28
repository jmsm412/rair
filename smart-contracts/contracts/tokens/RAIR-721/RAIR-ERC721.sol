// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35; 

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC721Storage } from "@solidstate/contracts/storage/ERC721Storage.sol";
import { RAIR721Storage } from "./AppStorage.sol";
import { ERC721AccessControlRoles } from "./AccessControlRoles.sol";
import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";

interface Factory {
    function getFacetSource() external view returns (address);
}

interface IDiamondReadable {
    function facetAddress(bytes4 selector) external view returns (address);
}

contract RAIR721_Diamond is ERC721AccessControlRoles, ERC165, AccessControlEnumerable {
    
    constructor(
        string memory name_,
        string memory symbol_,
        address creatorAddress_,
        uint16 creatorRoyalty_
    ) {
        ERC721Storage.ref().name = name_;
        ERC721Storage.ref().symbol = symbol_;

        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        store.requiresTrader = true;
        store.factoryAddress = msg.sender;
        store.royaltyFee = creatorRoyalty_;

        _setRoleAdmin(MINTER, CREATOR);
        _setRoleAdmin(TRADER, CREATOR);
        _grantRole(CREATOR, creatorAddress_);
        _grantRole(MINTER, creatorAddress_);
        _grantRole(TRADER, creatorAddress_);
    }

    function getFactoryAddress() public view returns (address factoryAddress) {
        factoryAddress = RAIR721Storage.layout().factoryAddress;
    }

    function contractURI() public view returns (string memory contractMetadataURI) {
        contractMetadataURI = RAIR721Storage.layout().contractMetadataURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    fallback() external {
        address factoryAddr = RAIR721Storage.layout().factoryAddress;
        address facetSource = Factory(factoryAddr).getFacetSource();
        address facet = IDiamondReadable(facetSource).facetAddress(msg.sig);
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }
}