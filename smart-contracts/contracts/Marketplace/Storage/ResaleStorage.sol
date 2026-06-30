// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

library ResaleStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("rair.contracts.storage.resaleOffers");

    struct FeeSplits {
        address recipient;
        uint256 percentage;
    }

    struct ResaleOffer {
        address erc721;
        address buyer;
        address seller;
        uint256 token;
        uint256 tokenPrice;
        address nodeAddress;
    }

    struct Layout {
        mapping(address => FeeSplits[]) royaltySplits;
        mapping(address => address) contractOwner;
        uint256 purchaseGracePeriod;
        uint256 decimalPow;
        ResaleOffer[] resaleOffers;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}