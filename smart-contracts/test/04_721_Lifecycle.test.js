const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { getSelectors, FacetCutAction_ADD } = require("./helpers/diamondUtils");

describe("04 - Complete RAIR721 & Marketplace Lifecycle", function () {

    async function deployFullEcosystemFixture() {
        const [owner, creator, buyer, seller, treasury, node] = await ethers.getSigners();

        const ERC20 = await ethers.getContractFactory("RAIR20");
        const erc20 = await ERC20.deploy("RAIR Payment", "RAIR", 1000000, owner.address);

        const FacetSource = await ethers.getContractFactory("FacetSource");
        const facetSource = await FacetSource.deploy();

        const MockRangesFacet = await ethers.getContractFactory("FactoryPointsFacet"); 
        const mockRangesFacet = await MockRangesFacet.deploy();
        
        const sourceCut = await ethers.getContractAt("IDiamondCut", facetSource.address);
        await sourceCut.diamondCut([
            { 
                facetAddress: mockRangesFacet.address, 
                action: FacetCutAction_ADD, 
                functionSelectors: ["0x9cb6c95c", "0xa42b4421"] 
            }
        ], ethers.constants.AddressZero, "0x");

        const FactoryDiamond = await ethers.getContractFactory("FactoryDiamond");
        const factoryProxy = await FactoryDiamond.deploy();

        const FactoryAdminFacet = await ethers.getContractFactory("FactoryAdminFacet");
        const adminFacet = await FactoryAdminFacet.deploy();
        const FactoryDeployerFacet = await ethers.getContractFactory("FactoryDeployerFacet");
        const deployerFacet = await FactoryDeployerFacet.deploy();

        const factoryCut = await ethers.getContractAt("IDiamondCut", factoryProxy.address);
        await factoryCut.diamondCut([
            { facetAddress: adminFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(adminFacet) },
            { facetAddress: deployerFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(deployerFacet) }
        ], ethers.constants.AddressZero, "0x");

        const factoryAdmin = await ethers.getContractAt("FactoryAdminFacet", factoryProxy.address);
        const factoryDeployer = await ethers.getContractAt("FactoryDeployerFacet", factoryProxy.address);

        await factoryAdmin.changeToken(erc20.address, 100);
        await factoryAdmin.setFacetSource(facetSource.address);

        const MarketplaceDiamond = await ethers.getContractFactory("MarketplaceDiamond");
        const marketProxy = await MarketplaceDiamond.deploy();

        const MarketAdminFacet = await ethers.getContractFactory("MarketplaceAdminFacet");
        const marketAdmin = await MarketAdminFacet.deploy();
        const ResalesFacet = await ethers.getContractFactory("ResaleFacet");
        const marketResales = await ResalesFacet.deploy();
        const MintingOffersFacet = await ethers.getContractFactory("MintingOffersFacet");
        const marketMinting = await MintingOffersFacet.deploy();

        const marketCut = await ethers.getContractAt("IDiamondCut", marketProxy.address);
        await marketCut.diamondCut([
            { facetAddress: marketAdmin.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(marketAdmin) },
            { facetAddress: marketResales.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(marketResales) },
            { facetAddress: marketMinting.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(marketMinting) }
        ], ethers.constants.AddressZero, "0x");

        const connectedMarketAdmin = await ethers.getContractAt("MarketplaceAdminFacet", marketProxy.address);
        const connectedMarketResales = await ethers.getContractAt("ResaleFacet", marketProxy.address);
        const connectedMarketMinting = await ethers.getContractAt("MintingOffersFacet", marketProxy.address);

        await connectedMarketAdmin.updateTreasuryAddress(treasury.address);

        await erc20.transfer(creator.address, 1000);
        await erc20.connect(creator).approve(factoryDeployer.address, 1000);

        const tx = await factoryDeployer.connect(creator).deployContract("Universal Collection", "UNI");
        const receipt = await tx.wait();
        const event = receipt.events.find(e => e.event === "DeployedContract");
        const cloneAddress = event.args.deploymentAddress;

        return {
            owner, creator, buyer, seller, treasury, node,
            erc20, factoryProxy, facetSource, cloneAddress,
            marketAdmin: connectedMarketAdmin,
            marketResales: connectedMarketResales,
            marketMinting: connectedMarketMinting
        };
    }

    describe("Dynamic Execution Router via Fallback Gateway", function () {
        it("Should correctly resolve gateway addresses on deployed clone structures", async function () {
            const { cloneAddress, facetSource } = await loadFixture(deployFullEcosystemFixture);
            const cloneInstance = await ethers.getContractAt("RAIR721_Diamond", cloneAddress);

            expect(await cloneInstance.getFacetSourceAddress()).to.equal(facetSource.address);
        });

        it("Should return accurate standard interfaces on custom clone lookups", async function () {
            const { cloneAddress } = await loadFixture(deployFullEcosystemFixture);
            const cloneInstance = await ethers.getContractAt("RAIR721_Diamond", cloneAddress);

            expect(await cloneInstance.supportsInterface("0x80ac58cd")).to.be.true;
        });
    });

    describe("Primary Minting Offers Configuration & Settlement", function () {
        it("Should register a primary sale allocation structural mapping on the marketplace", async function () {
            const { marketMinting, maintainer, cloneAddress, node } = await loadFixture(deployFullEcosystemFixture);

            const feeSplits = [
                { recipient: node.address, canBeContract: false, percentage: 500 }
            ];

            await expect(
                marketMinting.createMintingOffer(cloneAddress, node.address, 0, feeSplits)
            ).to.emit(marketMinting, "MintingOfferAdded");
        });
    });

    describe("Peer-to-Peer Resale Marketplace Signatures & Royalties", function () {
        it("Should allow the token owner to configure granular custom collection splits", async function () {
            const { marketResales, cloneAddress, creator } = await loadFixture(deployFullEcosystemFixture);
            const MAINTAINER_ROLE = await marketResales.MAINTAINER();

            await marketResales.grantRole(MAINTAINER_ROLE, creator.address);
            await marketResales.connect(creator).setContractOwner(cloneAddress, creator.address);

            const splits = [
                { recipient: creator.address, percentage: 10000 }
            ];

            await expect(
                marketResales.connect(creator).setRoyaltySplits(cloneAddress, splits)
            ).to.not.be.reverted;
        });

        it("Should reject listing updates if executing account is not authorized owner", async function () {
            const { marketResales, cloneAddress, buyer } = await loadFixture(deployFullEcosystemFixture);

            const splits = [
                { recipient: buyer.address, percentage: 10000 }
            ];

            await expect(
                marketResales.connect(buyer).setRoyaltySplits(cloneAddress, splits)
            ).to.be.revertedWith("Resale: Caller is not the contract owner");
        });

        it("Should verify cryptographically signed resale orders and process financial distribution", async function () {
            const { marketResales, cloneAddress, buyer, seller, node } = await loadFixture(deployFullEcosystemFixture);

            const tokenPrice = ethers.utils.parseEther("1.0");
            const gracePeriod = 3600;
            const RESALE_ADMIN_ROLE = await marketResales.RESALE_ADMIN();

            await marketResales.setGracePeriod(gracePeriod);
            await marketResales.grantRole(RESALE_ADMIN_ROLE, seller.address);

            const hash = await marketResales.generateResaleHash(
                cloneAddress,
                buyer.address,
                seller.address,
                1,
                tokenPrice,
                node.address
            );

            const signature = await seller.signMessage(ethers.utils.arrayify(hash));

            await expect(
                marketResales.connect(buyer).purchaseTokenOffer(
                    cloneAddress,
                    buyer.address,
                    seller.address,
                    1,
                    tokenPrice,
                    node.address,
                    signature,
                    { value: tokenPrice }
                )
            ).to.not.be.reverted;
        });
    });
});