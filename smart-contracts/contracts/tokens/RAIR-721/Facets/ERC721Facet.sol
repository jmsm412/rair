// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import { NonFungibleToken } from "@solidstate/contracts/token/non_fungible/NonFungibleToken.sol";
import { NonFungibleTokenMetadata } from "@solidstate/contracts/token/non_fungible/metadata/NonFungibleTokenMetadata.sol";
import { _NonFungibleToken } from "@solidstate/contracts/token/non_fungible/_NonFungibleToken.sol";
import { _NonFungibleTokenMetadata } from "@solidstate/contracts/token/non_fungible/metadata/_NonFungibleTokenMetadata.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { _Context } from "@solidstate/contracts/meta/_Context.sol";
import { RAIR721Storage } from "../AppStorage.sol";
import { ERC721AccessControlRoles } from "../AccessControlRoles.sol";
import { AccessControlEnumerable } from "../../../common/DiamondStorage/AccessControlEnumerable.sol";

interface IRAIR721 {
    event ProductCompleted(uint256 indexed productIndex);
    event RangeCompleted(uint256 indexed rangeIndex, uint256 productIndex);
    event TradingUnlocked(uint256 indexed rangeIndex, uint256 from, uint256 to);
}

abstract contract ERC721Facet is
    NonFungibleToken,
    NonFungibleTokenMetadata,
    ERC721AccessControlRoles,
    IRAIR721,
    AccessControlEnumerable
{
    error RangeDoesNotExist(uint256 rangeIndex);
    error ProductTokensExhausted(uint256 productIndex);
    error RangeTokensExhausted(uint256 rangeIndex);
    error MintingNotAllowedForRange(uint256 rangeIndex);
    error InvalidTokenIndexInRange(uint256 indexInRange, uint256 rangeStart, uint256 rangeEnd);
    error NoTokensAvailableForMinting(uint256 rangeIndex);
    error ArrayLengthMismatch();
    error EmptyArray();
    error TransferFromLockedRange(uint256 rangeIndex);

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(_NonFungibleToken, _NonFungibleTokenMetadata) {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from != address(0) && to != address(0)) {
            RAIR721Storage.Layout storage store = RAIR721Storage.layout();
            if (store.requiresTrader) {
                _checkRole(TRADER, msg.sender);
            }
            uint256 rangeId = store.tokenToRange[tokenId];
            if (store.ranges[rangeId].lockedTokens > 0) {
                revert TransferFromLockedRange(rangeId);
            }
        }
    }

    function _msgSender() internal view virtual override(Context, _Context) returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual override(Context, _Context) returns (bytes calldata) {
        return msg.data;
    }

    function nextMintableTokenInRange(uint256 rangeIndex) public view returns (uint256 index) {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        if (store.ranges.length <= rangeIndex) {
            revert RangeDoesNotExist(rangeIndex);
        }
        RAIR721Storage.Range memory selectedRange = store.ranges[rangeIndex];
        RAIR721Storage.Product memory selectedProduct = store.products[store.rangeToProduct[rangeIndex]];
        for (index = selectedRange.rangeStart; index < selectedRange.rangeEnd; index++) {
            if (_ownerOf(selectedProduct.startingToken + index) == address(0)) {
                return index;
            }
        }
        revert NoTokensAvailableForMinting(rangeIndex);
    }

    function _mintFromRange(address to, uint256 rangeId, uint256 indexInRange) internal {
        RAIR721Storage.Layout storage store = RAIR721Storage.layout();
        if (store.ranges.length <= rangeId) {
            revert RangeDoesNotExist(rangeId);
        }
        RAIR721Storage.Range storage selectedRange = store.ranges[rangeId];
        RAIR721Storage.Product storage selectedProduct = store.products[store.rangeToProduct[rangeId]];
        
        if (selectedProduct.mintableTokens == 0) {
            revert ProductTokensExhausted(store.rangeToProduct[rangeId]);
        }
        if (selectedRange.mintableTokens == 0) {
            revert RangeTokensExhausted(rangeId);
        }
        if (selectedRange.tokensAllowed == 0) {
            revert MintingNotAllowedForRange(rangeId);
        }
        if (indexInRange < selectedRange.rangeStart || indexInRange > selectedRange.rangeEnd) {
            revert InvalidTokenIndexInRange(indexInRange, selectedRange.rangeStart, selectedRange.rangeEnd);
        }

        _safeMint(to, selectedProduct.startingToken + indexInRange, "");
        
        selectedRange.tokensAllowed--;
        selectedRange.mintableTokens--;
        if (selectedRange.mintableTokens == 0) {
            emit RangeCompleted(rangeId, store.rangeToProduct[rangeId]);
        }
        
        if (selectedRange.lockedTokens > 0) {
            selectedRange.lockedTokens--;
            if (selectedRange.lockedTokens == 0) {
                emit TradingUnlocked(rangeId, selectedRange.rangeStart, selectedRange.rangeEnd);
            }
        }
        
        selectedProduct.mintableTokens--;
        if (selectedProduct.mintableTokens == 0) {
            emit ProductCompleted(store.rangeToProduct[rangeId]);
        }
        
        store.tokenToProduct[selectedProduct.startingToken + indexInRange] = store.rangeToProduct[rangeId];
        store.tokenToRange[selectedProduct.startingToken + indexInRange] = rangeId;
        store.tokensByProduct[store.rangeToProduct[rangeId]].push(selectedProduct.startingToken + indexInRange);
    }

    function mintFromRangeBatch(
        address[] calldata to,
        uint256 rangeId,
        uint256[] calldata indexInRange
    ) external onlyRole(MINTER) {
        if (to.length == 0) {
            revert EmptyArray();
        }
        if (to.length != indexInRange.length) {
            revert ArrayLengthMismatch();
        }
        for (uint256 i = 0; i < to.length; i++) {
            _mintFromRange(to[i], rangeId, indexInRange[i]);
        }
    }

    function mintFromRange(address to, uint256 rangeId, uint256 indexInRange) external onlyRole(MINTER) {
        _mintFromRange(to, rangeId, indexInRange);
    }
}