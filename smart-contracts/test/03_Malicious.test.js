const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("03 - Security & Boundary Limits", function () {
    it("Should successfully process standard withdrawals", async function () {
        const [owner] = await ethers.getSigners();
        const ReceiverTest = await ethers.getContractFactory("ReceiverTest");
        const receiver = await ReceiverTest.deploy();

        // Send ETH to contract
        await owner.sendTransaction({ to: receiver.address, value: ethers.utils.parseEther("1.0") });
        
        const initialBalance = await owner.getBalance();
        await receiver.withdraw();
        const finalBalance = await owner.getBalance();
        
        expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should prevent fallback attacks and trigger revert hooks", async function () {
        const [owner] = await ethers.getSigners();
        const Attacker = await ethers.getContractFactory("ReceiveEthAttacker");
        const attacker = await Attacker.deploy();

        await expect(
            owner.sendTransaction({ to: attacker.address, value: ethers.utils.parseEther("1.0") })
        ).to.be.revertedWith("Unexpected Revert Attack!");
    });
});