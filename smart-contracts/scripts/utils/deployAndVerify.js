import hre from "hardhat";

const wasteTime = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export const deploy = async (deploymentName, args = [], deployerAddress) => {
    const { deployments } = hre;
    const { deploy: runDeploy } = deployments;
    const deployment = await runDeploy(deploymentName, { 
        from: deployerAddress,
        waitConfirmations: 6,
        args,
    });
    const address = deployment.address || deployment.receipt?.contractAddress;
    console.log(`${deploymentName} deployed on address: ${address}`);
    return deployment;
};

export const verify = async (deployment, args) => {
    if (deployment.newlyDeployed) {
        await wasteTime(60000);
        try {
            const address = deployment.address || deployment.receipt?.contractAddress;
            await hre.run("verify:verify", {
                address: address,
                constructorArguments: args
            });
        } catch (err) {
            console.error(err);
        }
    }
};

export const deployAndVerify = async (contractName, args, deployerAddress) => {
    const deploymentData = await deploy(contractName, args, deployerAddress);
    await verify(deploymentData, args);
    return deploymentData;
};