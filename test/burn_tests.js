const { expect } = require("chai");
const { ethers } = require("hardhat");

let prevMonths = 0;

function addMonth(month) {
  prevMonths += month;
  let blockchainTime = Math.round((new Date()).getTime() / 1000);
  blockchainTime = blockchainTime + (prevMonths * 30 * 86400);
  return blockchainTime;
}

const bigNum = num => (num + '0'.repeat(18))

describe("Burn tests", function () {

  let deployerAccount;
  let nonExcludedAccountFirst;
  let pulse;
  let minter;

  before(async function () {
    const [deployer, nonExcludedFirst] = await ethers.getSigners();
    deployerAccount = deployer;
    nonExcludedAccountFirst = nonExcludedFirst;
    console.log(
      "Deploying contracts with the account:",
      deployer.address
    );

    console.log("Account balance:", (await deployer.getBalance()).toString());
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

  it("Should mint half of the tokens for the owner and burn half of them", async function () {
    await minter.mintHalfByOwner(deployerAccount.address);
    expect(parseInt(await pulse.balanceOf(deployerAccount.address))).to.equal(bigNum(500000000) / 10 ** 9);
    await pulse.includeInReward(deployerAccount.address);
    await pulse.burn('250000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('250000000000000000');
  });

});
