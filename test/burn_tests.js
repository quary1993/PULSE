/*

for this test to work, "_burn" should be make public

*/

// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// const bigNum = num => (num + '0'.repeat(18));

// describe("Supply burn tests", function () {
//     let pulse;

//     beforeEach(async function () {
//         const Minter = await ethers.getContractFactory("PulseManager");
//         minter = await Minter.deploy();
//         const Pulse = await ethers.getContractFactory("Pulse");
//         pulse = await Pulse.deploy(bigNum(1), minter.address);
//         await pulse.deployed();
//         minter.setTokenAddress(pulse.address);
//         minter.setTokenPrice(bigNum(1));
//     });

//     it("Should burn 50% of the total amount and tokens", async function() {
//         await pulse._burn('500000000000000000');
//         expect(await pulse.totalSupply()).to.equal('500000000000000000');
//     });
// });