/*

    WIP

*/

// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// const bigNum = num => (num + '0'.repeat(18));

// describe("Full enivroment tests", function () {
//     let deployerAccount;
//     let nonExcludedAccountFirst;
//     let nonExcludedAccountSecond;
//     let pulse;
//     let minter;

//     before(async function () {
//         const [deployer, nonExcludedFirst, nonExcludedSecond, nonExcludedThird] = await ethers.getSigners();
//         deployerAccount = deployer;
//         nonExcludedAccountFirst = nonExcludedFirst;
//         nonExcludedAccountSecond = nonExcludedSecond;
//         nonExcludedAccountThird = nonExcludedThird;
//     });

//     beforeEach(async function () {
//         const Minter = await ethers.getContractFactory("PulseManager");
//         minter = await Minter.deploy();
//         const Pulse = await ethers.getContractFactory("Pulse");
//         pulse = await Pulse.deploy(bigNum(1), minter.address);
//         await pulse.deployed();
//         minter.setTokenAddress(pulse.address);
//         minter.setTokenPrice(bigNum(1));
//     });

//     it("Should create PULSE-BNB pair and add liquidity to it", async function () {
//         //minting half of the total amount of tokens, for the owner
//         await minter.mintHalfByOwner(deployerAccount.address);
//         expect(parseInt(await pulse.balanceOf(deployerAccount.address))).to.equal(bigNum(500000000) / 10 ** 9);

//         //initialize public sale and 

//         //addding liquidity to the PULSE-WETH pair
//         const UniswapV2Router = await ethers.getContractFactory("UniswapV2Router02");
//         const uniswapV2Router = await UniswapV2Router.attach("0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
//         await pulse.setReviveLaunchDomeAddress(nonExcludedAccountThird.address);
//         await pulse.resumeTransactions();
//         await pulse.approve(uniswapV2Router.address, 1000000000);
//         await uniswapV2Router.addLiquidityETH(pulse.address, 1000000000, 1, 1, deployerAccount.address, 10429362993, { value: 1000000000 });
//     });



// })