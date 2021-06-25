const { expect } = require("chai");
const { ethers } = require("hardhat");

function toTimestamp(year,month,day,hour,minute,second){
    var datum = new Date(Date.UTC(year,month-1,day,hour,minute,second));
    return datum.getTime()
}

const bigNum = num=>(num + '0'.repeat(9))

describe("Mint", function() {

    let deployerAddress;
    let testerAddress;
    let account;

    before(async function () {
        const [deployer, tester] = await ethers.getSigners();
        deployerAddress = deployer.address;
        testerAddress = tester.address;
        account = deployer;
        console.log(
            "Deploying contracts with the account:",
            deployer.address
        );

        console.log("Account balance:", (await deployer.getBalance()).toString());
    })

  // beforeEach(async function() {
  //   const Pulse = await ethers.getContractFactory("Pulse");
  //   const pulse = await Pulse.deploy();
  //   await pulse.deployed();
  // })

  it("Should update normal account balance after mint", async function() {
    const Pulse = await ethers.getContractFactory("Pulse");
    const pulse = await Pulse.deploy();
    await pulse.deployed();
    await pulse._mint(testerAddress, bigNum(100));
    expect(parseInt(await pulse.balanceOf(testerAddress))).to.greaterThan(0);
  });

  it("Should update expected account balance after mint", async function() {
    const Pulse = await ethers.getContractFactory("Pulse");
    const pulse = await Pulse.deploy();
    await pulse.deployed();
    await pulse._mint(deployerAddress, bigNum(1));
    expect(parseInt(await pulse.balanceOf(deployerAddress))).to.greaterThan(0);
  });

  //improve this test
  it("Should return the amount of tokens from total tokens baased on a percentage", async function() {
    const Pulse = await ethers.getContractFactory("Pulse");
    const pulse = await Pulse.deploy();
    await pulse.deployed();
    const percentage = await pulse._percentageToAmountMintedToken(50);
  });

  it("Should mint 50% of the total tokens for the owner", async function() {
    const Pulse = await ethers.getContractFactory("Pulse");
    const pulse = await Pulse.deploy();
    await pulse.deployed();
    const ownerBalanceBeforeMint = await pulse.balanceOf(deployerAddress);
    await pulse.mintHalfByOwner(deployerAddress);
    expect(parseInt(await pulse.balanceOf(deployerAddress))).to.greaterThan(parseInt(ownerBalanceBeforeMint));
  });


})
