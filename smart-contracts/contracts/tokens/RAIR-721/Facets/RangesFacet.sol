// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { RAIR721Storage } from "../AppStorage.sol";
import { ERC721AccessControlRoles } from "../AccessControlRoles.sol";
import { AccessControlEnumerable } from "../../../common/DiamondStorage/AccessControlEnumerable.sol";

abstract contract RAIRRangesFacet is AccessControlEnumerable, ERC721AccessControlRoles {
    
    event CreatedRange(uint256 productIndex, uint256 start, uint256 end, uint256 price, uint256 tokensAllowed, uint256 lockedTokens, string name, uint256 rangeIndex);
    event UpdatedRange(uint256 rangeId, string name, uint256 price, uint256 tokensAllowed, uint256 lockedTokens);
    event TradingLocked(uint256 indexed rangeId, uint256 from, uint256 to, uint256 lockedTokens);
    event TradingUnlocked(uint256 indexed rangeId, uint256 from, uint256 to);

    struct RangeData {
        uint256 rangeLength;
        uint256 price;
        uint256 tokensAllowed;
        uint256 lockedTokens;
        string name;
    }

    error RangeDoesNotExist(uint256 rangeId);
    error CollectionDoesNotExist(uint256 collectionId);
    error InvalidRangeIndex();
    error InvalidMinimumPrice();
    error AllowedTokensExceedMintable();
    error LockedTokensExceedMintable();
    error AllowedTokensExceedRangeLength();
    error LockedTokensExceedRangeLength();
    error RangeExceedsCollectionLimits();
    error EmptyArray();

    modifier rangeExists(uint256 rangeId) {
        if (RAIR721Storage.layout().ranges.length <= rangeId) {
            revert RangeDoesNotExist(rangeId);
        }
        _;
    }

    modifier collectionExists(uint256 collectionId) {
        if (RAIR721Storage.layout().products.length <= collectionId) {
            revert CollectionDoesNotExist(collectionId);
        }
        _;
    }

    function rangeToProduct(uint256 rangeId) public view rangeExists(rangeId) returns (uint256) {
        return RAIR721Storage.layout().rangeToProduct[rangeId];
    }

    function rangeInfo(uint256 rangeId) external view rangeExists(rangeId) returns (RAIR721Storage.Range memory data, uint256 productIndex) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        data = store.ranges[rangeId];
        productIndex = store.rangeToProduct[rangeId];
    }

    function isRangeLocked(uint256 rangeId) external view rangeExists(rangeId) returns (bool) {
        return RAIR721Storage.layout().ranges[rangeId].lockedTokens > 0;
    }

    function productRangeInfo(uint256 collectionId, uint256 rangeIndex)
        external
        view
        collectionExists(collectionId)
        returns (RAIR721Storage.Range memory data)
    {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        if (store.products[collectionId].rangeList.length <= rangeIndex) {
            revert InvalidRangeIndex();
        }
        data = store.ranges[store.products[collectionId].rangeList[rangeIndex]];
    }

    function updateRange(
        uint256 rangeId,
        string calldata name,
        uint256 price,
        uint256 tokensAllowed,
        uint256 lockedTokens
    ) public rangeExists(rangeId) onlyRole(CREATOR) {
        if (price != 0 && price < 100) {
            revert InvalidMinimumPrice();
        }
        RAIR721Storage.Range storage selectedRange = RAIR721Storage.layout().ranges[rangeId];
        if (tokensAllowed > selectedRange.mintableTokens) {
            revert AllowedTokensExceedMintable();
        }
        if (lockedTokens > selectedRange.mintableTokens + 1) {
            revert LockedTokensExceedMintable();
        }
        
        selectedRange.tokensAllowed = tokensAllowed;
        if (lockedTokens > 0 && selectedRange.lockedTokens == 0) {
            emit TradingLocked(
                rangeId,
                selectedRange.rangeStart,
                selectedRange.rangeEnd,
                lockedTokens
            );
        } else if (lockedTokens == 0 && selectedRange.lockedTokens > 0) {
            emit TradingUnlocked(
                rangeId,
                selectedRange.rangeStart,
                selectedRange.rangeEnd
            );
        }
        selectedRange.lockedTokens = lockedTokens;
        selectedRange.rangePrice = price;
        selectedRange.rangeName = name;
        emit UpdatedRange(rangeId, name, price, tokensAllowed, lockedTokens);
    }

    function canCreateRange(uint256 productId, uint256 rangeStart, uint256 rangeEnd) public view returns (bool) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        uint256[] memory rangeList = store.products[productId].rangeList;
        uint256 len = rangeList.length;
        for (uint256 i = 0; i < len; i++) {
            RAIR721Storage.Range memory currentRange = store.ranges[rangeList[i]];
            if ((currentRange.rangeStart <= rangeStart && currentRange.rangeEnd >= rangeStart) || 
                (currentRange.rangeStart <= rangeEnd && currentRange.rangeEnd >= rangeEnd)) {
                return false;
            }
        }
        return true;
    }
    
    function _createRange(
        uint256 productId,
        uint256 rangeLength,
        uint256 price,
        uint256 tokensAllowed,
        uint256 lockedTokens,
        string memory name
    ) internal {
        if (price != 0 && price < 100) {
            revert InvalidMinimumPrice();
        }
        if (rangeLength < tokensAllowed) {
            revert AllowedTokensExceedRangeLength();
        }
        if (rangeLength < lockedTokens) {
            revert LockedTokensExceedRangeLength();
        }
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        RAIR721Storage.Product storage selectedProduct = store.products[productId];
        uint256 lastTokenFromPreviousRange;
        uint256 rangesLen = selectedProduct.rangeList.length;
        if (rangesLen > 0) {
            lastTokenFromPreviousRange = store.ranges[selectedProduct.rangeList[rangesLen - 1]].rangeEnd + 1;
        }

        RAIR721Storage.Range storage newRange = store.ranges.push();
        uint256 rangeIndex = store.ranges.length - 1;

        if (lastTokenFromPreviousRange + rangeLength - 1 > selectedProduct.endingToken) {
            revert RangeExceedsCollectionLimits();
        }

        newRange.rangeStart = lastTokenFromPreviousRange;
        newRange.rangeEnd = lastTokenFromPreviousRange + rangeLength - 1;
        newRange.tokensAllowed = tokensAllowed;
        newRange.mintableTokens = rangeLength;
        newRange.lockedTokens = lockedTokens;
        
        if (lockedTokens > 0) {
            emit TradingLocked(rangeIndex, newRange.rangeStart, newRange.rangeEnd, newRange.lockedTokens);
        } else {
            emit TradingUnlocked(rangeIndex, newRange.rangeStart, newRange.rangeEnd);
        }
        newRange.rangePrice = price;
        newRange.rangeName = name;
        store.rangeToProduct[rangeIndex] = productId;
        selectedProduct.rangeList.push(rangeIndex);

        emit CreatedRange(
            productId,
            newRange.rangeStart,
            newRange.rangeEnd,
            newRange.rangePrice,
            newRange.tokensAllowed,
            newRange.lockedTokens,
            newRange.rangeName,
            rangeIndex
        );
    }

    function createRange(
        uint256 collectionId,
        uint256 rangeLength,
        uint256 price,
        uint256 tokensAllowed,
        uint256 lockedTokens,
        string calldata name
    ) external onlyRole(CREATOR) collectionExists(collectionId) {
        _createRange(collectionId, rangeLength, price, tokensAllowed, lockedTokens, name);
    }

    function createRangeBatch(
        uint256 collectionId,
        RangeData[] calldata data
    ) external onlyRole(CREATOR) collectionExists(collectionId) {
        uint256 len = data.length;
        if (len == 0) {
            revert EmptyArray();
        }
        for (uint256 i = 0; i < len; i++) {
            _createRange(collectionId, data[i].rangeLength, data[i].price, data[i].tokensAllowed, data[i].lockedTokens, data[i].name);
        }
    }
}