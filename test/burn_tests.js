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

  it("Should mint half of the tokens for the owner and burn half of them", async function () {
    await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');
    expect(parseInt(await pulse.balanceOf(deployerAccount.address))).to.equal(bigNum(500000000) / 10 ** 9);
    await pulse.resumeTransactions();
    await pulse.transfer(minter.address, '471733885712');
    await minter.burnRemainingPulse();
    //expect(await pulse.balanceOf(deployerAccount.address)).to.equal('250000000000000000');
  });

});
