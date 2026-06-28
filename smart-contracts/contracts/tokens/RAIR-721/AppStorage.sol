// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

library RAIR721Storage {
    bytes32 internal constant STORAGE_SLOT = keccak256("rair.contracts.storage.RAIR721");

    struct Product {
        uint256 startingToken;
        uint256 endingToken;
        uint256 mintableTokens;
        string name;
        uint256[] rangeList;
    }

    struct Range {
        uint256 rangeStart;
        uint256 rangeEnd;
        uint256 tokensAllowed;
        uint256 mintableTokens;
        uint256 lockedTokens;
        uint256 rangePrice;
        string rangeName;
    }

    struct Layout {
        string baseURI;
        address factoryAddress;
        uint16 royaltyFee;
        Product[] products;
        Range[] ranges;
        mapping(uint256 => uint256) tokenToProduct;
        mapping(uint256 => uint256) tokenToRange;
        mapping(uint256 => string) uniqueTokenURI;
        mapping(uint256 => string) productURI;
        mapping(uint256 => bool) appendTokenIndexToProductURI;
        bool appendTokenIndexToBaseURI;
        mapping(uint256 => uint256[]) tokensByProduct;
        string contractMetadataURI;
        mapping(uint256 => uint256) rangeToProduct;
        mapping(uint256 => bool) _minted;
        mapping(uint256 => string) rangeURI;
        mapping(uint256 => bool) appendTokenIndexToRangeURI;
        string _metadataExtension;
        bool requiresTrader;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}