// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

library MarketplaceStorage {
    bytes32 internal constant STORAGE_SLOT =
        keccak256("rair.contracts.storage.MarketplaceApp");

    struct FeeSplits {
        address recipient;
        bool canBeContract;
        uint256 percentage;
    }

    struct MintingOffer {
        address erc721Address;
        address nodeAddress;
        uint256 rangeIndex;
        FeeSplits[] fees;
        bool visible;
    }

    struct Layout {
        uint16 decimals;
        uint256 decimalPow;
        uint256 nodeFee;
        uint256 treasuryFee;
        address treasuryAddress;
        MintingOffer[] mintingOffers;
        mapping(address => mapping(uint256 => uint256)) addressToRangeOffer;
        mapping(address => uint256[]) addressToOffers;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}