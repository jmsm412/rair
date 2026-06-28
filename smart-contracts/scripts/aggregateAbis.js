import fs from 'fs';
import path from 'path';

const ARTIFACTS_DIR = './artifacts/contracts';
const OUTPUT_DIR = './generated';
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'DiamondCombined.json');

const TARGET_DISPATCH_PATHS = [
    '../client/src/abis/DiamondCombined.json',
    '../event-worker/src/abis/DiamondCombined.json'
];

function findArtifacts(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    files.forEach(file => {
        const filePath = path.join(dir, file);
        if (fs.statSync(filePath).isDirectory()) {
            findArtifacts(filePath, fileList);
        } else if (file.endsWith('.json') && !file.endsWith('.dbg.json')) {
            fileList.push(filePath);
        }
    });
    return fileList;
}

export async function aggregate() {
    if (!fs.existsSync(ARTIFACTS_DIR)) {
        console.error("Artifacts directory not found. Please run 'npm run build' first.");
        return;
    }

    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    const artifactPaths = findArtifacts(ARTIFACTS_DIR);
    const combinedAbi = [];
    const seenSelectors = new Set();

    const facetNames = [
        "DiamondCutFacet",
        "DiamondLoupeFacet",
        "OwnershipFacet",
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

    for (const artifactPath of artifactPaths) {
        const contractClass = path.basename(artifactPath, '.json');
        if (!facetNames.includes(contractClass)) {
            continue;
        }

        const data = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
        if (!data.abi) {
            continue;
        }

        for (const element of data.abi) {
            if (element.type === 'function') {
                const signature = `${element.name}(${element.inputs.map(i => i.type).join(',')})`;
                if (!seenSelectors.has(signature)) {
                    seenSelectors.add(signature);
                    combinedAbi.push(element);
                }
            } else if (element.type === 'error' || element.type === 'event') {
                combinedAbi.push(element);
            }
        }
    }

    const outputContent = JSON.stringify({ abi: combinedAbi }, null, 2);
    fs.writeFileSync(OUTPUT_FILE, outputContent);
    console.log(`Successfully generated aggregated ABI at: ${OUTPUT_FILE}`);

    for (const targetPath of TARGET_DISPATCH_PATHS) {
        try {
            const targetDir = path.dirname(targetPath);
            if (!fs.existsSync(targetDir)) {
                fs.mkdirSync(targetDir, { recursive: true });
            }
            fs.writeFileSync(targetPath, outputContent);
            console.log(`Dispatched ABI resource to: ${targetPath}`);
        } catch (error) {
            console.error(`Failed to dispatch ABI to ${targetPath}:`, error.message);
        }
    }
}

if (process.argv[1] && process.argv[1].endsWith('aggregateAbis.js')) {
    aggregate();
}