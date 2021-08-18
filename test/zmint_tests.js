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

describe("Mint tests", function () {

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
    pulse = await Pulse.deploy(bigNum(1), minter.address, "0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
    await pulse.deployed();
    minter.setTokenAddress(pulse.address);
    minter.setTokenPrice(bigNum(1));
  });

  it("Should revert because the caller is not the minter contract", async function () {
    await expect(pulse.mint(deployerAccount.address, '499999999000000000')).to.be.reverted;
  });

  it("Should mint 2 PULSE tokens for an excluded account", async function () {
    await minter.initPublicSale();
    await minter.connect(deployerAccount).publicSale({ value: bigNum(2) });
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('3000000000');
  });

  it("Should mint 2 PULSE tokens for an non excluded account", async function () {
    await minter.initPublicSale();
    await minter.connect(nonExcludedAccountFirst).publicSale({ value: bigNum(2) });
    expect(parseInt(await pulse.balanceOf(nonExcludedAccountFirst.address))).to.equal(bigNum(2) / 10 ** 9);
  });

  it("Should mint half of the tokens for the owner", async function () {
    await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');
    expect(parseInt(await pulse.balanceOf(deployerAccount.address))).to.equal(bigNum(50) / 10 ** 2);
  });

  it("Should revert periodic mint because date is to small", async function () {
    let redeedmTime = addMonth(3);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await expect(minter.periodicMint('499999999000000000')).to.be.reverted;
  });

  it("Should mint a reward in two or more calls", async function () {
    let redeedmTime = addMonth(7);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await expect(minter.periodicMint('25000000000000000'));
    await expect(minter.periodicMint('25000000000000000')).to.be.not.reverted;
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('50000001000000000');
  });

  it("Should mint 5% after 6 months", async function () {
    let redeedmTime = addMonth(7);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('50000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('50000001000000000');
  });

  it("Should mint 10% after 12 months", async function () {
    let redeedmTime = addMonth(13);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('100000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('100000001000000000');
  });

  it("Should mint 10% after 18 months", async function () {
    let redeedmTime = addMonth(19);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('100000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('100000001000000000');
  });

  it("Should mint 15% after 24 months", async function () {
    let redeedmTime = addMonth(25);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('240000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('240000001000000000');
  });

  it("Should mint 15% after 12 months", async function () {
    let redeedmTime = addMonth(13);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('150000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('150000001000000000');
  });

  it("Should mint 25% after 18 months", async function () {
    let redeedmTime = addMonth(19);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('250000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('250000001000000000');
  });

  it("Should mint 40% after 24 months", async function () {
    let redeedmTime = addMonth(25);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('400000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('400000001000000000');
  });


  it("Should mint all tokens", async function () {
    //sets token price to equal 1 bnb
    await pulse.connect(deployerAccount).setTokenPrice(1);
    await minter.connect(deployerAccount).setTokenPrice(1);

    //mint all tokens from periodic mint in one call
    let redeedmTime = addMonth(25);
    await ethers.provider.send('evm_setNextBlockTimestamp', [redeedmTime]);
    await ethers.provider.send('evm_mine');
    await minter.periodicMint('400000000000000000');
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('400000001000000000');
    await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000')
    expect(await pulse.balanceOf(deployerAccount.address)).to.equal('900000000000000000');
    //termina testul
    await minter.initPublicSale();
    await minter.connect(nonExcludedAccountFirst).publicSale({ value: '100000000'});
    expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('100000000000000000');
    expect(await minter.getMintedTokensTotal()).to.equal('1000000000000000000');
  })
});
