const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Swap and liquify tests", function () {
    let deployerAccount;
    let nonExcludedAccountFirst;
    let nonExcludedAccountSecond;
    let pulse;
    let minter;

    before(async function () {
        const [deployer, nonExcludedFirst, nonExcludedSecond, nonExcludedThird] = await ethers.getSigners();
        deployerAccount = deployer;
        nonExcludedAccountFirst = nonExcludedFirst;
        nonExcludedAccountSecond = nonExcludedSecond;
        nonExcludedAccountThird = nonExcludedThird;
    });

    beforeEach(async function () {
        const Minter = await ethers.getContractFactory("PulseManager");
        minter = await Minter.deploy("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(minter.address, "0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        await pulse.deployed();
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(1);
    });

    it("Should create PULSE-ETH pair and add liquidity to it", async function () {
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');
        await pulse.setReviveLaunchDomeAddress(nonExcludedAccountThird.address);
        await pulse.resumeTransactions();
        await pulse.approve(uniswapV2Router.address, '100000000000000000');
        await uniswapV2Router.addLiquidityETH(pulse.address, '100000000000000000', 1, 1, deployerAccount.address, 10429362993, { value: 1000000000000 });
        await pulse.transfer(nonExcludedAccountFirst.address, '500000000');
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, 100000000);
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, 100000000);
        expect(await pulse.balanceOf(pulse.address)).to.equal('2000000');
    });

})