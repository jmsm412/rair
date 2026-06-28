// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { RAIR721Storage } from "../AppStorage.sol";
import { ERC721AccessControlRoles } from "../AccessControlRoles.sol";
import { AccessControlEnumerable } from "../../../common/DiamondStorage/AccessControlEnumerable.sol";

abstract contract RAIRProductFacet is AccessControlEnumerable, ERC721AccessControlRoles {
    
    event CreatedCollection(uint256 indexed collectionIndex, string collectionName, uint256 startingToken, uint256 collectionLength);

    error CollectionDoesNotExist(uint256 collectionId);
    error RangeDoesNotExist(uint256 rangeId);
    error TokenDoesNotExist(uint256 tokenId);
    error NoTokensAvailable(uint256 collectionId);

    modifier collectionExists(uint256 collectionId) {
        if (RAIR721Storage.layout().products.length <= collectionId) {
            revert CollectionDoesNotExist(collectionId);
        }
        _;
    }

    modifier rangeExists(uint256 rangeId) {
        if (RAIR721Storage.layout().ranges.length <= rangeId) {
            revert RangeDoesNotExist(rangeId);
        }
        _;
    }

    function ownsTokenInProduct(address find, uint256 productIndex) public view collectionExists(productIndex) returns (bool) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        uint256[] storage productTokens = store.tokensByProduct[productIndex];
        uint256 len = productTokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (_ownerOf(productTokens[i]) == find) {
                return true;
            }
        }
        return false;
    }

    function ownsTokenInRange(address find, uint256 rangeIndex) public view rangeExists(rangeIndex) returns (bool) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        RAIR721Storage.Range storage selectedRange = store.ranges[rangeIndex];
        uint256 productIndex = store.rangeToProduct[rangeIndex];
        uint256 startOfProduct = store.products[productIndex].startingToken;
        
        uint256 start = startOfProduct + selectedRange.rangeStart;
        uint256 end = startOfProduct + selectedRange.rangeEnd;

        for (uint256 i = start; i <= end; i++) {
            if (_ownerOf(i) == find) {
                return true;
            }
        }
        return false;
    }

    function tokenByProduct(uint256 productIndex, uint256 tokenIndex) public view collectionExists(productIndex) returns (uint256) {
        return RAIR721Storage.layout().tokensByProduct[productIndex][tokenIndex];
    }

    function productToToken(uint256 productIndex, uint256 tokenIndex) public view collectionExists(productIndex) returns (uint256) {
        return RAIR721Storage.layout().products[productIndex].startingToken + tokenIndex;
    }

    function tokenToProductIndex(uint256 tokenId) public view returns (uint256) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        uint256 productIndex = store.tokenToProduct[tokenId];
        if (store.products.length <= productIndex) {
            revert TokenDoesNotExist(tokenId);
        }
        return tokenId - store.products[productIndex].startingToken;
    }

    function tokenToProduct(uint256 tokenId) public view returns (uint256 productIndex, uint256 rangeIndex) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        productIndex = store.tokenToProduct[tokenId];
        rangeIndex = store.tokenToRange[tokenId];
    }

    function getProductCount() external view returns (uint256) {
        return RAIR721Storage.layout().products.length;
    }

    function getProductInfo(uint256 productIndex) external view collectionExists(productIndex) returns (RAIR721Storage.Product memory) {
        return RAIR721Storage.layout().products[productIndex];
    }

    function getNextSequentialIndex(uint256 collectionId, uint256 startingIndex, uint256 endingIndex) public view collectionExists(collectionId) returns (uint256) {
        RAIR721Storage.Product memory currentProduct = RAIR721Storage.layout().products[collectionId];
        uint256 start = currentProduct.startingToken + startingIndex;
        uint256 end = currentProduct.startingToken + endingIndex;
        
        for (uint256 i = start; i <= end; i++) {
            if (_ownerOf(i) == address(0)) {
                return i - currentProduct.startingToken;
            }
        }
        revert NoTokensAvailable(collectionId);
    }

    function hasTokenInProduct(address userAddress, uint256 productIndex, uint256 startingToken, uint256 endingToken) public view returns (bool) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        if (store.products.length <= productIndex) {
            return false;
        }
        RAIR721Storage.Product memory aux = store.products[productIndex];
        if (aux.endingToken != 0) {
            uint256[] storage userTokens = store.tokensByProduct[productIndex];
            uint256 len = userTokens.length;
            uint256 lowBound = aux.startingToken + startingToken;
            uint256 highBound = aux.startingToken + endingToken;

            for (uint256 i = 0; i < len; i++) {
                uint256 token = userTokens[i];
                if (_ownerOf(token) == userAddress && token >= lowBound && token <= highBound) {
                    return true;
                }
            }
        }
        return false;
    }

    function mintedTokensInProduct(uint256 productIndex) public view returns (uint256) {
        return RAIR721Storage.layout().tokensByProduct[productIndex].length;
    }

    function createProduct(string calldata productName, uint256 copies) public onlyRole(CREATOR) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        uint256 lastToken = store.products.length == 0 ? 0 : store.products[store.products.length - 1].endingToken + 1;
        
        RAIR721Storage.Product storage newProduct = store.products.push();
        newProduct.startingToken = lastToken;
        newProduct.endingToken = lastToken + copies - 1;
        newProduct.name = productName;
        newProduct.mintableTokens = copies;
        
        emit CreatedCollection(store.products.length - 1, productName, lastToken, copies);
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address);
}