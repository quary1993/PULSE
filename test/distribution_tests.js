const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Distribution tests", function () {
    let deployerAccount;
    let nonExcludedAccountFirst;
    let nonExcludedAccountSecond;
    let nonExcludedAccountThird;
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
        minter = await Minter.deploy();
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(bigNum(1), minter.address);
        await pulse.deployed();
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(bigNum(1));
    });

    it("Should transfer 2% of the amount (that is being transfered) to the revive launch dome address", async function () {
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        await minter.mintHalfByOwner(deployerAccount.address);
        await pulse.resumeTransactions();
        await pulse.approve(uniswapV2Router.address, 1000000000);
        await uniswapV2Router.addLiquidityETH(pulse.address, 1000000000, 1, 1, deployerAccount.address, 10429362993, { value: 1000000000 });
        
        const pulsePairAddress = await pulse.getPair();

        console.log("Owner: ", (await pulse.balanceOf(deployerAccount.address)).toString());
        console.log("1: ", (await pulse.balanceOf(nonExcludedAccountFirst.address)).toString());
        console.log("2: ", (await pulse.balanceOf(nonExcludedAccountSecond.address)).toString());
        console.log("3: ", (await pulse.balanceOf(nonExcludedAccountThird.address)).toString());
        //transfer a part of the tokens minted previously to a non excluded account
        await pulse.transfer(nonExcludedAccountFirst.address, '1900000000000000');
        console.log("Owner: ", (await pulse.balanceOf(deployerAccount.address)).toString());
        console.log("1: ", (await pulse.balanceOf(nonExcludedAccountFirst.address)).toString());
        console.log("2: ", (await pulse.balanceOf(nonExcludedAccountSecond.address)).toString());
        console.log("3: ", (await pulse.balanceOf(nonExcludedAccountThird.address)).toString()); 
        //transfer a part of the tokens minted previously to a non excluded account
        await pulse.transfer(nonExcludedAccountThird.address, '900000000000000');
        console.log("Owner: ", (await pulse.balanceOf(deployerAccount.address)).toString());
        console.log("1: ", (await pulse.balanceOf(nonExcludedAccountFirst.address)).toString());
        console.log("2: ", (await pulse.balanceOf(nonExcludedAccountSecond.address)).toString());
        console.log("3: ", (await pulse.balanceOf(nonExcludedAccountThird.address)).toString());
        //transfer the received tokens to another non excluded account (fee are being deducted) 
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '1000000000000000');
        console.log("Owner: ", (await pulse.balanceOf(deployerAccount.address)).toString());
        console.log("1: ", (await pulse.balanceOf(nonExcludedAccountFirst.address)).toString());
        console.log("2: ", (await pulse.balanceOf(nonExcludedAccountSecond.address)).toString());
        console.log("3: ", (await pulse.balanceOf(nonExcludedAccountThird.address)).toString());
        console.log("Minter: ", (await pulse.balanceOf(minter.address)).toString());
        console.log("Pair: ", (await pulse.balanceOf(pulsePairAddress)).toString());
        console.log("Pulse: ", (await pulse.balanceOf(pulse.address)).toString());
        console.log("Address(0): ", (await pulse.balanceOf(0x00)).toString());
        //checks if the balance of the account is bigger than 1000000000000000
        //that means the fees have been reflected and balances have increased
        expect(await pulse.balanceOf(nonExcludedAccountThird.address)).to.equal('1000010000100001');
    });
})