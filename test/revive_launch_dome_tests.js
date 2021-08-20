const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Revive launch dome tests", function () {
    let deployerAccount;
    let nonExcludedAccountFirst;
    let nonExcludedAccountSecond;
    let reviveLaunchDomeAccount;
    let pulse;
    let minter;

    before(async function () {
        const [deployer, nonExcludedFirst, nonExcludedSecond, reviveLaunchDome] = await ethers.getSigners();
        deployerAccount = deployer;
        nonExcludedAccountFirst = nonExcludedFirst;
        nonExcludedAccountSecond = nonExcludedSecond;
        reviveLaunchDomeAccount = reviveLaunchDome;
    });

    beforeEach(async function () {
        const Minter = await ethers.getContractFactory("PulseManager");
        minter = await Minter.deploy("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(minter.address, "0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        await pulse.deployed();
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(bigNum(1));
    });

    it("Should transfer 2% of the amount (that is being transfered) to the revive launch dome address", async function () {
        //initialize uniswapV2 router contract
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");

        //mint half of the total amount of tokens for the owner
        await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');
        await pulse.resumeTransactions();

        //add liqiudity to the PULSE->ETH pair
        await pulse.approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(pulse.address, '10000000000', 1, 1, deployerAccount.address, 10429362993, { value: '1000000000' });

        //set revive launch dome address
        await pulse.setReviveLaunchDomeAddress(reviveLaunchDomeAccount.address);

        //transfer 2 tokens from excluded to non excluded (no fees on the transfer)
        await pulse.transfer(nonExcludedAccountFirst.address, '20000000000');

        //transfer 1 token from non excluded to exclued (fees are applied)
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '10000000000');

        expect(await pulse.balanceOf(reviveLaunchDomeAccount.address)).to.equal('201041666');
    });

    it("Should leave the balance of reviveLaunchDomeAccount 0 because a transfer between one or two excluded accounts is being made", async function () {
        //initialize uniswapV2 router contract
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");

        //mint half of the total amount of tokens for the owner
        await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');
        await pulse.resumeTransactions();

        //add liqiudity to the PULSE->ETH pair
        await pulse.approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(pulse.address, '10000000000', 1, 1, deployerAccount.address, 10429362993, { value: '1000000000' });

        //set revive launch dome address
        await pulse.setReviveLaunchDomeAddress(reviveLaunchDomeAccount.address);

        //transfer 2 tokens from excluded to non excluded (no fees on the transfer)
        await pulse.transfer(nonExcludedAccountFirst.address, '20000000000');

        expect(await pulse.balanceOf(reviveLaunchDomeAccount.address)).to.equal('0');
    });
});