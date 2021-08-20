const { expect } = require("chai");
const { ethers } = require("hardhat");

const bigNum = num => (num + '0'.repeat(18));

describe("Revive basket tests", function () {

    //accounts
    let deployerAccount;
    let nonExcludedAccountFirst;
    let nonExcludedAccountSecond;

    //contracts
    let pulse;
    let minter;
    let token_1;
    let token_2;

    before(async function () {
        const [deployer, first, second] = await ethers.getSigners();
        deployerAccount = deployer;
        nonExcludedAccountFirst = first;
        nonExcludedAccountSecond = second;
    });

    beforeEach(async function () {
        //deploy minter
        const Minter = await ethers.getContractFactory("PulseManager");
        minter = await Minter.deploy("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        const Pulse = await ethers.getContractFactory("Pulse");
        pulse = await Pulse.deploy(minter.address, "0xD99D1c33F9fC3444f8101754aBC46c52416550D1");
        await pulse.deployed();

        //set minter internal variables
        minter.setTokenAddress(pulse.address);
        minter.setTokenPrice(1);

        //deploy one erc20 token
        const Token_1 = await ethers.getContractFactory("UniswapV2ERC20");
        token_1 = await Token_1.deploy("Token 1", "TKN1", 18);
        await token_1.deployed();
        token_2 = await Token_1.deploy("Token 2", "TKN2", 9);
    });

    it("Should revert because the owner doesn't have enough lp's because of the lack of liquidity", async function () {
        //initialize uniswapV2 router contract
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");

        //adds token_1 to the revive basket array
        await minter.addToken(token_1.address, 230);
        expect(await minter.getTokenWeight(token_1.address)).to.equal('230');

        //mint half of the total amount of tokens for the owner
        await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');

        await pulse.resumeTransactions();

        //add liqiudity to the PULSE->ETH pair
        await pulse.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(pulse.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '1000000000' });

        // transfer 2 tokens from excluded to non excluded (no fees on the transfer)
        await pulse.transfer(nonExcludedAccountFirst.address, '20000000000');

        // transfer 1 token from non excluded to non exclued (fees are applied)
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '10000000000');
        //check if the fees were properly applied
        expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('10052631578');
        expect(await pulse.balanceOf(nonExcludedAccountSecond.address)).to.equal('9047368421');

        await token_1.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(token_1.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '10000000000' });

        await expect(minter.redeemLpTokens(token_1.address, '10000')).to.be.reverted;

    });


    it("Should reedem lp tokens generated from revive basket functionality", async function () {
        //initialize uniswapV2 router contract
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");

        //add liquidity for the token_1 -> eth pair
        await token_1.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(token_1.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '10000000000' });

        //adds token_1 to the revive basket array
        await minter.addToken(token_1.address, 230);
        expect(await minter.getTokenWeight(token_1.address)).to.equal('230');

        //mint half of the total amount of tokens for the owner
        await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');

        await pulse.resumeTransactions();

        //add liqiudity to the PULSE->ETH pair
        await pulse.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(pulse.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '1000000000' });

        // transfer 2 tokens from excluded to non excluded (no fees on the transfer)
        await pulse.transfer(nonExcludedAccountFirst.address, '20000000000');

        // transfer 1 token from non excluded to non exclued (fees are applied)
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '10000000000');
        //check if the fees were properly applied
        expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('10052631578');
        expect(await pulse.balanceOf(nonExcludedAccountSecond.address)).to.equal('9047368421');

        await minter.redeemLpTokens(token_1.address, '10000');
    });


    it("Should reedem lp tokens generated from revive basket functionality", async function () {
        //initialize uniswapV2 router contract
        const UniswapV2Router = await ethers.getContractFactory("PancakeRouter");
        const uniswapV2Router = await UniswapV2Router.attach("0xD99D1c33F9fC3444f8101754aBC46c52416550D1");

        //add liquidity for the token_1 -> eth pair
        await token_1.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(token_1.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '10000000000' });

        //adds token_1 to the revive basket array
        await minter.addToken(token_1.address, 230);
        expect(await minter.getTokenWeight(token_1.address)).to.equal('230');

        //add liquidity for the token_2 -> eth pair
        await token_1.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(token_1.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '10000000000' });


        //adds token_2 to the revive basket array
        await minter.addToken(token_2.address, 690);
        expect(await minter.getTokenWeight(token_2.address)).to.equal('690');

        //mint half of the total amount of tokens for the owner
        await minter.mintHalfByOwner(deployerAccount.address, '499999999000000000');

        await pulse.resumeTransactions();

        //add liqiudity to the PULSE->ETH pair
        await pulse.connect(deployerAccount).approve(uniswapV2Router.address, '10000000000');
        await uniswapV2Router.addLiquidityETH(pulse.address, '10000000000', 0, 0, deployerAccount.address, 1689318817, { value: '1000000000' });

        // transfer 2 tokens from excluded to non excluded (no fees on the transfer)
        await pulse.transfer(nonExcludedAccountFirst.address, '20000000000');

        // transfer 1 token from non excluded to non exclued (fees are applied)
        await pulse.connect(nonExcludedAccountFirst).transfer(nonExcludedAccountSecond.address, '10000000000');
        //check if the fees were properly applied
        expect(await pulse.balanceOf(nonExcludedAccountFirst.address)).to.equal('10052631578');
        expect(await pulse.balanceOf(nonExcludedAccountSecond.address)).to.equal('9047368421');

        await expect(minter.redeemLpTokens(token_1.address, '10000')).to.not.be.reverted;
    });
});