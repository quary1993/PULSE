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
        const UniswapV2Router = await ethers.getContractFactory("UniswapV2Router02");
        const uniswapV2Router = await UniswapV2Router.attach("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
        await minter.mintHalfByOwner(deployerAccount.address);
        await pulse.resumeTransactions();
        await pulse.approve(uniswapV2Router.address, 1000000000);
        await uniswapV2Router.addLiquidityETH(pulse.address, 1000000000, 1, 1, deployerAccount.address, 10429362993, { value: 1000000000 });

        //transfer a part of the tokens minted previously to a non excluded account
        await pulse.transfer(nonExcludedAccountFirst.address, '4000000000000000');

        //transfer a part of the tokens minted previously to a non excluded account
        await pulse.transfer(nonExcludedAccountThird.address, '1000000000000000');

        //transfer the received tokens to another non excluded account (fee are being deducted) 
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '1000000000000000');

        //checks if the balance of the account is bigger than 1000000000000000
        //that means the fees have been reflected and balances have increased
        expect(await pulse.balanceOf(nonExcludedAccountThird.address)).to.equal('1000010000100001');
    });
})