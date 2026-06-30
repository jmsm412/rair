const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { getSelectors, FacetCutAction_ADD } = require("./helpers/diamondUtils");

describe("02 - Marketplace System", function () {
    async function deployMarketplaceFixture() {
        const [owner, maintainer, treasury, node, seller, buyer] = await ethers.getSigners();

        const ERC20 = await ethers.getContractFactory("RAIR20");
        const erc20 = await ERC20.deploy("RAIR Payment", "RAIR", 1000000, owner.address);

        const MarketplaceDiamond = await ethers.getContractFactory("MarketplaceDiamond");
        const marketProxy = await MarketplaceDiamond.deploy();

        const AdminFacet = await ethers.getContractFactory("MarketplaceAdminFacet");
        const adminFacet = await AdminFacet.deploy();

        const ResalesFacet = await ethers.getContractFactory("ResaleFacet");
        const resalesFacet = await ResalesFacet.deploy();

        const MintingOffersFacet = await ethers.getContractFactory("MintingOffersFacet");
        const mintingFacet = await MintingOffersFacet.deploy();

        const marketCut = await ethers.getContractAt("IDiamondCut", marketProxy.address);
        await marketCut.diamondCut([
            { facetAddress: adminFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(adminFacet) },
            { facetAddress: resalesFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(resalesFacet) },
            { facetAddress: mintingFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(mintingFacet) }
        ], ethers.constants.AddressZero, "0x");

        const marketAdmin = await ethers.getContractAt("MarketplaceAdminFacet", marketProxy.address);
        const marketResales = await ethers.getContractAt("ResaleFacet", marketProxy.address);
        const marketMinting = await ethers.getContractAt("MintingOffersFacet", marketProxy.address);

        const MAINTAINER_ROLE = await marketAdmin.MAINTAINER();
        await marketAdmin.grantRole(MAINTAINER_ROLE, maintainer.address);
        await marketAdmin.connect(maintainer).updateTreasuryAddress(treasury.address);
        await marketAdmin.connect(maintainer).updateDecimals(3);

        const MockRAIR721 = await ethers.getContractFactory("ERC20Exchange"); 
        const mockNFT = await MockRAIR721.deploy(ethers.constants.AddressZero);

        return { 
            owner, maintainer, treasury, node, seller, buyer, 
            erc20, marketProxy, marketAdmin, marketResales, marketMinting, mockNFT 
        };
    }

    describe("Admin & Fee Configuration", function () {
        it("Should allow a Maintainer to update the treasury address", async function () {
            const { marketAdmin, maintainer, buyer } = await loadFixture(deployMarketplaceFixture);
            await expect(marketAdmin.connect(maintainer).updateTreasuryAddress(buyer.address))
                .to.emit(marketAdmin, "UpdatedTreasuryAddress")
                .withArgs(buyer.address);
                
            expect(await marketAdmin.getTreasuryAddress()).to.equal(buyer.address);
        });

        it("Should fail if a non-Maintainer tries to update fees", async function () {
            const { marketAdmin, buyer } = await loadFixture(deployMarketplaceFixture);
            await expect(
                marketAdmin.connect(buyer).updateNodeFee(500)
            ).to.be.revertedWith("AccessControl: account");
        });
    });

    describe("MultiSend Functionality (Consolidated)", function () {
        it("Should batch transfer ERC20 tokens to multiple recipients securely", async function () {
            const { marketAdmin, erc20, seller, buyer, treasury } = await loadFixture(deployMarketplaceFixture);
            const transferAmount = 500;
            await erc20.approve(marketAdmin.address, transferAmount * 3);

            const recipients = [seller.address, buyer.address, treasury.address];
            const amounts = [100, 200, 200];

            await marketAdmin.multiSendERC20(erc20.address, recipients, amounts);

            expect(await erc20.balanceOf(seller.address)).to.equal(100);
            expect(await erc20.balanceOf(buyer.address)).to.equal(200);
            expect(await erc20.balanceOf(treasury.address)).to.equal(200);
        });
    });

    describe("Minting Offers Data Management & Financial Routing Rules", function () {
        it("Should allow Maintainer to create a minting offer and retrieve its fees", async function () {
            const { marketMinting, maintainer, node, treasury } = await loadFixture(deployMarketplaceFixture);
            const dummyErc721 = treasury.address;
            const rangeIndex = 0;
            const feeSplits = [
                { recipient: node.address, canBeContract: false, percentage: 50 },
                { recipient: treasury.address, canBeContract: false, percentage: 50 }
            ];

            await expect(
                marketMinting.connect(maintainer).createMintingOffer(
                    dummyErc721, node.address, rangeIndex, feeSplits
                )
            ).to.emit(marketMinting, "MintingOfferAdded").withArgs(dummyErc721, rangeIndex, 0);

            const count = await marketMinting.getMintingOfferCount();
            expect(count).to.equal(1);

            const offerData = await marketMinting.getMintingOffer(0);
            expect(offerData.visible).to.be.true;
            expect(offerData.feeCount).to.equal(2);
        });

        it("Should prevent purchase if an offer visibility configuration is false", async function () {
            const { marketMinting, maintainer, mockNFT, node } = await loadFixture(deployMarketplaceFixture);
            const feeSplits = [{ recipient: node.address, canBeContract: false, percentage: 5000 }];
            await marketMinting.connect(maintainer).createMintingOffer(mockNFT.address, node.address, 0, feeSplits);
            await marketMinting.connect(maintainer).changeOfferVisibility(0, false);

            await expect(
                marketMinting.buyMintingOfferBatch(0, [1], [node.address], { value: 100 })
            ).to.be.revertedWith("Minter Marketplace: Offer hidden!");
        });

        it("Should reject purchase if value provided does not equal aggregated item range cost", async function () {
            const { marketMinting, maintainer, mockNFT, node, buyer } = await loadFixture(deployMarketplaceFixture);
            const feeSplits = [{ recipient: node.address, canBeContract: false, percentage: 5000 }];
            await marketMinting.connect(maintainer).createMintingOffer(mockNFT.address, node.address, 0, feeSplits);

            await expect(
                marketMinting.connect(buyer).buyMintingOfferBatch(0, [1, 2], [buyer.address, buyer.address], { value: 0 })
            ).to.be.reverted;
        });
    });
});