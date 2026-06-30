const { ethers } = require("hardhat");
const { getSelectors, FacetCutAction_ADD } = require('./diamondUtils');

async function deployCoreEcosystemFixture() {
    const [owner, creator, buyer, treasury, node] = await ethers.getSigners();

    // 1. Deploy Base Token
    const ERC20 = await ethers.getContractFactory("RAIR20");
    const erc20 = await ERC20.deploy("RAIR Token", "RAIR", 1000000, owner.address);

    // 2. Deploy Facet Source (The master registry for RAIR721 clones)
    const FacetSource = await ethers.getContractFactory("FacetSource");
    const facetSource = await FacetSource.deploy();

    // 3. Deploy Factory Diamond & Consolidated Facets
    const FactoryDiamond = await ethers.getContractFactory("FactoryDiamond");
    const factoryProxy = await FactoryDiamond.deploy();

    const FactoryAdminFacet = await ethers.getContractFactory("FactoryAdminFacet");
    const adminFacet = await FactoryAdminFacet.deploy();
    
    const FactoryDeployerFacet = await ethers.getContractFactory("FactoryDeployerFacet");
    const deployerFacet = await FactoryDeployerFacet.deploy();
    
    const FactoryPointsFacet = await ethers.getContractFactory("FactoryPointsFacet");
    const pointsFacet = await FactoryPointsFacet.deploy();

    // Attach facets to Diamond
    const factoryCut = await ethers.getContractAt("IDiamondCut", factoryProxy.address);
    await factoryCut.diamondCut([
        { facetAddress: adminFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(adminFacet) },
        { facetAddress: deployerFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(deployerFacet) },
        { facetAddress: pointsFacet.address, action: FacetCutAction_ADD, functionSelectors: getSelectors(pointsFacet) }
    ], ethers.constants.AddressZero, "0x");

    // Initialize Factory State
    const factoryAdmin = await ethers.getContractAt("FactoryAdminFacet", factoryProxy.address);
    await factoryAdmin.changeToken(erc20.address, 150);
    await factoryAdmin.setFacetSource(facetSource.address);

    return { 
        owner, creator, buyer, treasury, node, 
        erc20, factoryProxy, facetSource,
        adminFacet: factoryAdmin,
        deployerFacet: await ethers.getContractAt("FactoryDeployerFacet", factoryProxy.address),
        pointsFacet: await ethers.getContractAt("FactoryPointsFacet", factoryProxy.address)
    };
}

module.exports = { deployCoreEcosystemFixture };