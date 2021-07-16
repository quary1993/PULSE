const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Revive basket tokens handling tests", function () {
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

    it("Should add a token to the revive basket tokens array", async function () {
        await minter.addToken(pulse.address, 230);
        expect(await minter._getTokenWeight(pulse.address)).to.equal('230');
        await minter.removeToken(pulse.address);
    });

    it("Should remove a token from the revive basket tokens array", async function () {
        await minter.addToken(pulse.address, 230);
        await minter.removeToken(pulse.address);
        expect(await minter._getTokenWeight(pulse.address)).to.equal('0');
    })

})