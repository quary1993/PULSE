const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Transfer tests", function () {
    let deployerAccount;
    let nonExcludedAccountFirst;
    let nonExcludedAccountSecond;
    let pulse;
    let minter;

    before(async function () {
        const [deployer, nonExcludedFirst, nonExcludedSecond] = await ethers.getSigners();
        deployerAccount = deployer;
        nonExcludedAccountFirst = nonExcludedFirst;
        nonExcludedAccountSecond = nonExcludedSecond;
    });

    beforeEach(async function () {
        const Minter = await ethers.getContractFactory("Minter");
        minter = await Minter.deploy();
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(bigNum(1), minter.address);
        await pulse.deployed();
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(bigNum(1));
    });

    // it("Should transfer 10 tokens from excluded to excluded without taking fees", async function () {
    //     await pulse.excludeFromReward(nonExcludedAccountFirst.address);
    //     await pulse.resumeTransactions();
    //     await minter.mintHalfByOwner(deployerAccount.address);
    //     await pulse.transfer(nonExcludedAccountFirst.address, '10000000000');
    //     expect(await pulse.balanceOf(deployerAccount.address)).to.equal("499999990000000000");
    //     expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('10000000000');
    // });

    it("Should transfer 10 tokens from excluded to non excluded without taking fees", async function () {
        await pulse.resumeTransactions();
        await minter.mintHalfByOwner(deployerAccount.address);
        expect(await pulse.balanceOf(deployerAccount.address)).to.equal("500000000000000000");
        expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('0');
        await pulse.transfer(nonExcludedAccountFirst.address, '10000000000');
        expect(await pulse.balanceOf(deployerAccount.address)).to.equal("499999990000000000");
        expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('10000000000');
    });

    // it("Should transfer 10 tokens from non excluded to excluded without taking fees", async function () {
    //     //initialize uniswapV2 router contract
    //     const UniswapV2Router = await ethers.getContractFactory("UniswapV2Router02");
    //     const uniswapV2Router = await UniswapV2Router.attach("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
        
    //     //mint half of the total amount of tokens for the owner
    //     await minter.mintHalfByOwner(deployerAccount.address);
    //     await pulse.resumeTransactions();
    
    //     //transfer 2 tokens from excluded to non excluded (no fees on the transfer)
    //     await pulse.transfer(nonExcludedAccountFirst.address, '10000000000');

    //     //transfer 1 token from non excluded to exclued (fees are applied)
    //     await pulse.connect(nonExcludedAccountFirst).transfer(deployerAccount.address, '10000000000');

    //     //check if the fees were properly applied
    //     expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('0');
    //     expect(await pulse.balanceOf(deployerAccount.address)).to.equal('500000000000000000');
    // });

    // it("Should transfer 10 tokens from non excluded to non excluded taking fees", async function () {
    //     //initialize uniswapV2 router contract
    //     const UniswapV2Router = await ethers.getContractFactory("UniswapV2Router02");
    //     const uniswapV2Router = await UniswapV2Router.attach("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
        
    //     //mint half of the total amount of tokens for the owner
    //     await minter.mintHalfByOwner(deployerAccount.address);
    //     await pulse.resumeTransactions();
        
    //     //add liqiudity to the PULSE->ETH pair
    //     await pulse.approve(uniswapV2Router.address, '10000000000');
    //     await uniswapV2Router.addLiquidityETH(pulse.address, '10000000000', 1, 1, deployerAccount.address, 10429362993, { value: '1000000000' });
        
    //     //transfer 2 tokens from excluded to non excluded (no fees on the transfer)
    //     await pulse.transfer(nonExcludedAccountFirst.address, '20000000000');

    //     //transfer 1 token from non excluded to non exclued (fees are applied)
    //     await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '10000000000');

    //     //check if the fees were properly applied
    //     expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('10000000001');
    //     expect(await pulse.balanceOf(nonExcludedAccountSecond.address)).to.equal('8700000001');
    // });
});