const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Uniswap V2 ERC-2O Token Functionalities", function () {

    //accounts
    let deployerAccount;
    let secondaryAccount;

    //contracts
    let uniswapERC20Token;

    before(async function () {
        const [deployer, secondary] = await ethers.getSigners();
        deployerAccount = deployer;
        secondaryAccount = secondary;
    });

    beforeEach(async function () {
        const UniswapERC20Token = await ethers.getContractFactory("UniswapV2ERC20");
        uniswapERC20Token = await UniswapERC20Token.deploy("UniswapV2ERC20", "UNISW", 18);
    });

    it("Should deploy the uniswap v2 erc20-token and initialize it with specified values", async function () {
        expect(await uniswapERC20Token.name()).to.equal('UniswapV2ERC20');
        expect(await uniswapERC20Token.symbol()).to.equal("UNISW");
        expect(await uniswapERC20Token.decimals()).to.equal(18);
    });

    it("Should check if deployer account has 100 tokens in it's balance", async function () {
        expect(await uniswapERC20Token.balanceOf(deployerAccount.address)).to.equal('100000000000000000000');
    });

    it("Should mint 10 tokens for the secondary account", async function () { 
        await uniswapERC20Token.mint(secondaryAccount.address, '10000000000000000000');
        expect(await uniswapERC20Token.balanceOf(secondaryAccount.address)).to.equal('10000000000000000000');
    });

    it("Should transfer 10 tokens from deployer account to secondary account", async function () {
        expect(await uniswapERC20Token.balanceOf(deployerAccount.address)).to.equal('100000000000000000000');
        await uniswapERC20Token.mint(secondaryAccount.address, '10000000000000000000');
        expect(await uniswapERC20Token.balanceOf(secondaryAccount.address)).to.equal('10000000000000000000');
        await uniswapERC20Token.approve(secondaryAccount.address, '10000000000000000000');
        expect(await uniswapERC20Token.allowance(deployerAccount.address, secondaryAccount.address)).to.equal('10000000000000000000');
        await uniswapERC20Token.connect(secondaryAccount).transferFrom(deployerAccount.address, secondaryAccount.address, '10000000000000000000');
        expect(await uniswapERC20Token.balanceOf(secondaryAccount.address)).to.equal('20000000000000000000');
    });
});