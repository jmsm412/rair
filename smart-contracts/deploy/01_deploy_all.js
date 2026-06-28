import hre from "hardhat";
import { ethers } from "ethers";
import { deployAndVerify } from "../scripts/utils/deployAndVerify.js";

const DEPLOY_FLAGS = {
    facets: true,
    erc20: false,
    erc20Exchange: false,
    diamondFactory: true,
    diamondMarketplace: true,
    facetSource: false
};

const getSelectors = (contract) => {
    const selectors = [];
    contract.interface.forEachFunction((fragment) => {
        selectors.push(fragment.selector);
    });
    return selectors;
};

const computeDiamondCut = async (proxyAddress, facetName, facetAddress, signer) => {
    const cut = [];
    try {
        const loupe = await hre.ethers.getContractAt("FactoryDiamond", proxyAddress, signer);
        const currentFacets = await loupe.facets();
        const selectorToAddress = {};
        for (const f of currentFacets) {
            for (const s of f.functionSelectors) {
                selectorToAddress[s] = f.facetAddress;
            }
        }

        const contractFactory = await hre.ethers.getContractFactory(facetName);
        const selectors = getSelectors(contractFactory);

        const toAdd = [];
        const toReplace = [];

        for (const s of selectors) {
            const currentAddress = selectorToAddress[s];
            if (!currentAddress) {
                toAdd.push(s);
            } else if (currentAddress.toLowerCase() !== facetAddress.toLowerCase()) {
                toReplace.push(s);
            }
        }

        if (toAdd.length > 0) {
            cut.push({
                facetAddress: facetAddress,
                action: 0,
                functionSelectors: toAdd
            });
        }
        if (toReplace.length > 0) {
            cut.push({
                facetAddress: facetAddress,
                action: 1,
                functionSelectors: toReplace
            });
        }
    } catch (e) {
        const contractFactory = await hre.ethers.getContractFactory(facetName);
        const selectors = getSelectors(contractFactory);
        cut.push({
            facetAddress: facetAddress,
            action: 0,
            functionSelectors: selectors
        });
    }
    return cut;
};

const deployAll = async ({ getUnnamedAccounts, deployments }) => {
    const [deployerAddress] = await getUnnamedAccounts();
    const { get } = deployments;
    const signer = await hre.ethers.getSigner(deployerAddress);

    const facetNames = [
        "ERC721EnumerableFacet",
        "RAIRMetadataFacet",
        "RAIRProductFacet",
        "RAIRRangesFacet",
        "RAIRRoyaltiesFacet",
        "CreatorsFacet",
        "DeployerFacet",
        "TokensFacet",
        "PointsDeposit",
        "PointsQuery",
        "PointsWithdraw",
        "MintingOffersFacet",
        "FeesFacet",
        "ResaleFacet",
        "MultiSendTool"
    ];

    const deployedFacets = {};

    if (DEPLOY_FLAGS.facets) {
        for await (const facet of facetNames) {
            const deployment = await deployAndVerify(facet, [], deployerAddress);
            deployedFacets[facet] = deployment.address || deployment.receipt?.contractAddress;
        }
    } else {
        for (const facet of facetNames) {
            const deployment = await get(facet);
            deployedFacets[facet] = deployment.address;
        }
    }

    if (DEPLOY_FLAGS.erc20) {
        await deployAndVerify('RAIR20', ["RAIR", "RAIR", ethers.parseUnits('1000000000', 18)], deployerAddress);
    }

    if (DEPLOY_FLAGS.erc20Exchange) {
        await deployAndVerify('ERC20Exchange', ["0x2b0fFbF00388f9078d5512256c43B983BB805eF8"], deployerAddress);
    }

    if (DEPLOY_FLAGS.diamondFactory) {
        let proxyAddress;
        let isNewDeploy = false;
        try {
            const existing = await get('FactoryDiamond');
            proxyAddress = existing.address;
        } catch (e) {
            const factoryDiamondData = await deployAndVerify('FactoryDiamond', [], deployerAddress);
            proxyAddress = factoryDiamondData.address || factoryDiamondData.receipt?.contractAddress;
            isNewDeploy = true;
        }

        const factoryFacets = [
            "CreatorsFacet",
            "DeployerFacet",
            "TokensFacet",
            "PointsDeposit",
            "PointsQuery",
            "PointsWithdraw"
        ];

        let fullCut = [];
        for (const name of factoryFacets) {
            if (isNewDeploy) {
                const contract = await hre.ethers.getContractAt(name, deployedFacets[name]);
                fullCut.push({
                    facetAddress: deployedFacets[name],
                    action: 0,
                    functionSelectors: getSelectors(contract)
                });
            } else {
                const facetCut = await computeDiamondCut(proxyAddress, name, deployedFacets[name], signer);
                fullCut = fullCut.concat(facetCut);
            }
        }

        if (fullCut.length > 0) {
            const diamondCutProxy = await hre.ethers.getContractAt("FactoryDiamond", proxyAddress, signer);
            const tx = await diamondCutProxy.diamondCut(fullCut, ethers.ZeroAddress, "0x");
            await tx.wait();
            console.log(`FactoryDiamond cut execution complete at address: ${proxyAddress}`);
        }
    }

    if (DEPLOY_FLAGS.diamondMarketplace) {
        let proxyAddress;
        let isNewDeploy = false;
        try {
            const existing = await get('MarketplaceDiamond');
            proxyAddress = existing.address;
        } catch (e) {
            const marketplaceDiamondData = await deployAndVerify('MarketplaceDiamond', [], deployerAddress);
            proxyAddress = marketplaceDiamondData.address || marketplaceDiamondData.receipt?.contractAddress;
            isNewDeploy = true;
        }

        const marketplaceFacets = [
            "MintingOffersFacet",
            "FeesFacet",
            "ResaleFacet",
            "MultiSendTool"
        ];

        let fullCut = [];
        for (const name of marketplaceFacets) {
            if (isNewDeploy) {
                const contract = await hre.ethers.getContractAt(name, deployedFacets[name]);
                fullCut.push({
                    facetAddress: deployedFacets[name],
                    action: 0,
                    functionSelectors: getSelectors(contract)
                });
            } else {
                const facetCut = await computeDiamondCut(proxyAddress, name, deployedFacets[name], signer);
                fullCut = fullCut.concat(facetCut);
            }
        }

        if (fullCut.length > 0) {
            const diamondCutProxy = await hre.ethers.getContractAt("MarketplaceDiamond", proxyAddress, signer);
            const tx = await diamondCutProxy.diamondCut(fullCut, ethers.ZeroAddress, "0x");
            await tx.wait();
            console.log(`MarketplaceDiamond cut execution complete at address: ${proxyAddress}`);
        }
    }

    if (DEPLOY_FLAGS.facetSource) {
        await deployAndVerify('FacetSource', [], deployerAddress);
    }
};

deployAll.tags = ['MasterDeployment'];
export default deployAll;