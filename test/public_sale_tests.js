const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Public sale tests", function () {
    let deployerAccount;
    let pulse;
    let minter;

    before(async function () {
        const [deployer, nonExcludedFirst, nonExcludedSecond, nonExcludedThird] = await ethers.getSigners();
        deployerAccount = deployer;
    });

    beforeEach(async function () {
        const Minter = await ethers.getContractFactory("PulseManager");
        minter = await Minter.deploy();
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(1, minter.address);
        await pulse.deployed();
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(1);
    });

    it("Should not permit buying tokens because public sale has not started", async function () {
        await expect(minter.publicSale({value: '1000000000000000000'})).to.be.reverted;
    });

    it("Should not permit buying tokens because the amount would exceed the 10% of the total amount of tokens", async function() {
        await minter.initPublicSale();
        await minter.publicSale({value: '100000000'});
        await expect(minter.publicSale({value: '100000000'})).to.be.reverted;
    });

    it("Should mint 1 token", async function () {
        await minter.initPublicSale();
        await minter.setTokenPrice(bigNum(1));
        await expect(minter.publicSale({value:bigNum(1)}));
        expect(await pulse.balanceOf(deployerAccount.address)).to.equal('1000000000');
    });
});