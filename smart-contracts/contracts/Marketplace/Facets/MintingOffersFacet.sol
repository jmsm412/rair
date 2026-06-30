// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";
import { MarketplaceStorage } from "../AppStorage.sol";

interface IRAIR721 {
    struct Range {
        uint256 rangeStart;
        uint256 rangeEnd;
        uint256 tokensAllowed;
        uint256 mintableTokens;
        uint256 lockedTokens;
        uint256 rangePrice;
        string rangeName;
    }
    function rangeInfo(uint256 rangeId) external view returns (Range memory data, uint256 productIndex);
    function mintFromRange(address to, uint256 rangeId, uint256 indexInRange) external;
}

contract MintingOffersFacet is AccessControlEnumerable {
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");

    event MintingOfferAdded(address indexed erc721Address, uint256 indexed rangeIndex, uint256 offerIndex);
    event MintingOfferVisibilityChanged(uint256 indexed offerIndex, bool visible);

    function createMintingOffer(
        address erc721Address,
        address nodeAddress,
        uint256 rangeIndex,
        MarketplaceStorage.FeeSplits[] calldata fees
    ) external onlyRole(MAINTAINER) {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        require(s.addressToRangeOffer[erc721Address][rangeIndex] == 0, "Minter Marketplace: Offer exists!");

        s.mintingOffers.push();
        uint256 offerIndex = s.mintingOffers.length - 1;
        MarketplaceStorage.MintingOffer storage newOffer = s.mintingOffers[offerIndex];
        
        newOffer.erc721Address = erc721Address;
        newOffer.nodeAddress = nodeAddress;
        newOffer.rangeIndex = rangeIndex;
        newOffer.visible = true;

        for (uint256 i = 0; i < fees.length; i++) {
            newOffer.fees.push(fees[i]);
        }

        s.addressToRangeOffer[erc721Address][rangeIndex] = s.mintingOffers.length;
        s.addressToOffers[erc721Address].push(offerIndex);

        emit MintingOfferAdded(erc721Address, rangeIndex, offerIndex);
    }

    function changeOfferVisibility(uint256 offerIndex, bool visibility) external onlyRole(MAINTAINER) {
        MarketplaceStorage.layout().mintingOffers[offerIndex].visible = visibility;
        emit MintingOfferVisibilityChanged(offerIndex, visibility);
    }

    function getMintingOfferCount() external view returns (uint256) {
        return MarketplaceStorage.layout().mintingOffers.length;
    }

    function getMintingOffer(uint256 index) external view returns (
        address erc721Address,
        address nodeAddress,
        uint256 rangeIndex,
        bool visible,
        uint256 feeCount
    ) {
        MarketplaceStorage.MintingOffer storage offer = MarketplaceStorage.layout().mintingOffers[index];
        return (offer.erc721Address, offer.nodeAddress, offer.rangeIndex, offer.visible, offer.fees.length);
    }

    function getMintingOfferFees(uint256 index, uint256 feeIndex) external view returns (address recipient, bool canBeContract, uint256 percentage) {
        MarketplaceStorage.FeeSplits storage fee = MarketplaceStorage.layout().mintingOffers[index].fees[feeIndex];
        return (fee.recipient, fee.canBeContract, fee.percentage);
    }

    function getOffersFromContract(address erc721Address) external view returns (uint256[] memory) {
        return MarketplaceStorage.layout().addressToOffers[erc721Address];
    }

    function buyMintingOfferBatch(
        uint256 offerIndex,
        uint256[] calldata tokenIndexes,
        address[] calldata recipients
    ) external payable {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        require(tokenIndexes.length == recipients.length, "Minter Marketplace: Array mismatch!");
        
        MarketplaceStorage.MintingOffer storage selectedOffer = s.mintingOffers[offerIndex];
        require(selectedOffer.visible, "Minter Marketplace: Offer hidden!");

        (IRAIR721.Range memory rangeData, ) = IRAIR721(selectedOffer.erc721Address).rangeInfo(selectedOffer.rangeIndex);

        if (rangeData.rangePrice > 0) {
            uint256 totalPrice = rangeData.rangePrice * tokenIndexes.length;
            require(msg.value == totalPrice, "Minter Marketplace: Incorrect payment!");

            uint256 totalTransferred = 0;
            uint256 nodePayment = (totalPrice * s.nodeFee) / (100 * s.decimalPow);
            uint256 treasuryPayment = (totalPrice * s.treasuryFee) / (100 * s.decimalPow);

            totalTransferred += nodePayment;
            totalTransferred += treasuryPayment;

            (bool successNode, ) = payable(selectedOffer.nodeAddress).call{value: nodePayment}("");
            require(successNode, "Marketplace: Node transfer failed");
            
            (bool successTreasury, ) = payable(s.treasuryAddress).call{value: treasuryPayment}("");
            require(successTreasury, "Marketplace: Treasury transfer failed");

            for (uint256 i = 0; i < selectedOffer.fees.length; i++) {
                uint256 auxMoneyToBeSent = (totalPrice * selectedOffer.fees[i].percentage) / (100 * s.decimalPow);
                totalTransferred += auxMoneyToBeSent;
                (bool successFee, ) = payable(selectedOffer.fees[i].recipient).call{value: auxMoneyToBeSent}("");
                require(successFee, "Marketplace: Fee transfer failed");
            }
            require(totalTransferred == totalPrice, "Minter Marketplace: Funds error!");
        }

        for (uint256 i = 0; i < tokenIndexes.length; i++) {
            IRAIR721(selectedOffer.erc721Address).mintFromRange(recipients[i], selectedOffer.rangeIndex, tokenIndexes[i]);
        }
    }
}