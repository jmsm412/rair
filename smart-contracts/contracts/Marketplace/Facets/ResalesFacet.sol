// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.35;

import { ResaleStorage } from "../Storage/ResaleStorage.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { AccessControlEnumerable } from "../../common/DiamondStorage/AccessControlEnumerable.sol";
import { SignedHashProtection } from "../../common/SignedHashProtection.sol";
import { MarketplaceStorage } from "../AppStorage.sol";

contract ResaleFacet is AccessControlEnumerable, SignedHashProtection {
    bytes32 public constant MAINTAINER = keccak256("MAINTAINER");
    bytes32 public constant RESALE_ADMIN = keccak256("RESALE_ADMIN");

    event TokenSold(address indexed erc721Address, address buyer, address seller, uint256 token, uint256 tokenPrice);
    event TokenOfferCreated(address indexed erc721Address, address seller, uint256 token, uint256 tokenPrice, uint256 offerId);
    event TokenOfferUpdated(uint256 offerId, uint256 newTokenPrice);
    event TokenOfferDeleted(uint256 offerId);

    modifier onlyOwnerOfContract(address erc721) {
        require(
            ResaleStorage.layout().contractOwner[erc721] == msg.sender,
            "Resale: Caller is not the contract owner"
        );
        _;
    }

    function setContractOwner(address erc721, address owner) external onlyRole(MAINTAINER) {
        ResaleStorage.layout().contractOwner[erc721] = owner;
    }

    function setRoyaltySplits(
        address erc721,
        ResaleStorage.FeeSplits[] calldata splits
    ) external onlyOwnerOfContract(erc721) {
        ResaleStorage.Layout storage data = ResaleStorage.layout();
        delete data.royaltySplits[erc721];
        
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < splits.length; i++) {
            totalPercentage += splits[i].percentage;
            data.royaltySplits[erc721].push(splits[i]);
        }
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        require(totalPercentage == 100 * s.decimalPow, "Resale: Royalties must equal 100%");
    }

    function setGracePeriod(uint256 gracePeriod) external onlyRole(MAINTAINER) {
        ResaleStorage.layout().purchaseGracePeriod = gracePeriod;
    }

    function createResaleOffer(
        address erc721,
        uint256 token,
        uint256 tokenPrice,
        address nodeAddress
    ) external {
        require(IERC721(erc721).ownerOf(token) == msg.sender, "Resale: Caller does not own token");
        ResaleStorage.Layout storage data = ResaleStorage.layout();
        
        data.resaleOffers.push(
            ResaleStorage.ResaleOffer({
                erc721: erc721,
                buyer: address(0),
                seller: msg.sender,
                token: token,
                tokenPrice: tokenPrice,
                nodeAddress: nodeAddress
            })
        );
        
        emit TokenOfferCreated(erc721, msg.sender, token, tokenPrice, data.resaleOffers.length - 1);
    }

    function updateResaleOffer(uint256 offerIndex, uint256 newPrice) external {
        ResaleStorage.ResaleOffer storage offer = ResaleStorage.layout().resaleOffers[offerIndex];
        require(offer.seller == msg.sender, "Resale: Caller is not the seller");
        require(offer.buyer == address(0), "Resale: Offer already filled");
        
        offer.tokenPrice = newPrice;
        emit TokenOfferUpdated(offerIndex, newPrice);
    }

    function generateResaleHash(
        address erc721,
        address buyer,
        address seller,
        uint256 token,
        uint256 tokenPrice,
        address nodeAddress
    ) public view returns (bytes32) {
        uint256 roundedTime = ((block.timestamp + ResaleStorage.layout().purchaseGracePeriod) / 100) * 100;
        return keccak256(abi.encodePacked(erc721, buyer, seller, token, tokenPrice, nodeAddress, roundedTime));
    }

    function getResaleOfferCount() public view returns (uint256) {
        return ResaleStorage.layout().resaleOffers.length;
    }

    function getResaleOffer(uint256 offerIndex) public view returns (ResaleStorage.ResaleOffer memory offer) {
        offer = ResaleStorage.layout().resaleOffers[offerIndex];
    }

    function purchaseGasTokenOffer(uint256 offerIndex) public payable {
        ResaleStorage.ResaleOffer storage offerData = ResaleStorage.layout().resaleOffers[offerIndex];
        require(offerData.buyer == address(0), "Resale: Offer already purchased");
        
        _distributeFees(offerData.erc721, offerData.tokenPrice, offerData.nodeAddress, offerData.seller);
        _sendToken(offerData.erc721, offerData.token, offerData.seller, msg.sender, offerData.tokenPrice);
        offerData.buyer = msg.sender;
    }

    function purchaseTokenOffer(
        address erc721,
        address buyer,
        address seller,
        uint256 token,
        uint256 tokenPrice,
        address nodeAddress,
        bytes memory signature
    ) public payable {
        bytes32 messageHash = generateResaleHash(erc721, buyer, seller, token, tokenPrice, nodeAddress);
        bytes32 ethSignedMessageHash = getSignedMessageHash(messageHash);
        require(
            hasRole(RESALE_ADMIN, recoverSigner(ethSignedMessageHash, signature)),
            "Resale: Invalid signature"
        );

        _distributeFees(erc721, tokenPrice, nodeAddress, seller);
        _sendToken(erc721, token, seller, buyer, tokenPrice);
    }

    function _distributeFees(
        address erc721,
        uint256 price,
        address nodeAddress,
        address seller
    ) internal {
        MarketplaceStorage.Layout storage s = MarketplaceStorage.layout();
        ResaleStorage.Layout storage data = ResaleStorage.layout();
        
        uint256 totalFees = s.nodeFee + s.treasuryFee;
        uint256 nodePayment = (price * s.nodeFee) / (100 * s.decimalPow);
        uint256 treasuryPayment = (price * s.treasuryFee) / (100 * s.decimalPow);
        
        (bool successNode, ) = payable(nodeAddress).call{value: nodePayment}("");
        require(successNode, "Resale: Node transfer failed");
        
        (bool successTreasury, ) = payable(s.treasuryAddress).call{value: treasuryPayment}("");
        require(successTreasury, "Resale: Treasury transfer failed");

        ResaleStorage.FeeSplits[] storage splits = data.royaltySplits[erc721];
        for (uint256 i = 0; i < splits.length; i++) {
            uint256 royaltyPayment = (price * splits[i].percentage) / (100 * s.decimalPow);
            (bool successRoyalty, ) = payable(splits[i].recipient).call{value: royaltyPayment}("");
            require(successRoyalty, "Resale: Royalty transfer failed");
            totalFees += splits[i].percentage;
        }

        uint256 remainingSellerProceeds = (price * ((100 * s.decimalPow) - totalFees)) / (100 * s.decimalPow);
        (bool successSeller, ) = payable(seller).call{value: remainingSellerProceeds}("");
        require(successSeller, "Resale: Seller transfer failed");
    }

    function _sendToken(
        address erc721,
        uint256 token,
        address seller,
        address buyer,
        uint256 tokenPrice
    ) internal {
        IERC721(erc721).safeTransferFrom(seller, buyer, token);
        emit TokenSold(erc721, buyer, seller, token, tokenPrice);
    }
}