// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.12;
import "./IPulseManager.sol";
import "../openzeppelin/contracts/token/IToken.sol";
import "../openzeppelin/contracts/libraries/Ownable.sol";
import "../openzeppelin/contracts/libraries/SafeMath.sol";
import "../openzeppelin/contracts/token/IERC20.sol";
import "../uniswap/periphery/IUniswapV2Router02.sol";
import "../uniswap/core/IUniswapV2Factory.sol";
import "../uniswap/core/IUniswapV2Pair.sol";
import "hardhat/console.sol";

contract PulseManager is IPulseManager, Ownable {
    using SafeMath for uint256;

    uint256 private creationTime = 0;
    uint256 private tokenPrice = 1;

    bool private publicSalePaused = true;
    uint256 private publicSaleMintedTokens = 0;

    bool private hasOwnerMintedHalf = false;
    uint256 private periodicMintedTokens = 0;

    address private pulseTokenAddress;
    IERC20 private pulseToken = IERC20(0x00);
    IUniswapV2Router02 private uniswapV2Router;
    IUniswapV2Factory private factory;

    struct reviveBasketToken {
        address tokenAddress;
        uint256 weight;
    }

    reviveBasketToken[] public reviveBasketTokens;
    uint256 private reviveBasketWeight = 0;

    constructor() public {
        creationTime = block.timestamp;
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        factory = IUniswapV2Factory(uniswapV2Router.factory());
    }

    //used to set the address of the token which has the _mint function
    function setTokenAddress(address _tokenAddress) external {
        pulseToken = IERC20(_tokenAddress);
        pulseTokenAddress = _tokenAddress;
    }

    //used to set the price of the token which has the _mint function
    function setTokenPrice(uint256 _tokenPrice) external {
        tokenPrice = _tokenPrice;
    }

    //converts percentage to amount from 1000000000
    function _percentageToAmountMintedToken(uint256 percentage)
        private
        pure
        returns (uint256)
    {
        uint256 amount = 10000000 * 10**9;
        amount = amount.mul(percentage);
        return amount;
    }

    //used to mint half of the total tokens to the owner
    function mintHalfByOwner(address to) external onlyOwner() {
        require(
            hasOwnerMintedHalf == false,
            "Mint: you can mint 50% of the tokens only one time!"
        );
        pulseToken.mint(to, _percentageToAmountMintedToken(50));
        hasOwnerMintedHalf = true;
    }

    //used to make publicSale function callable
    function initPublicSale() external onlyOwner() {
        publicSalePaused = false;
    }

    //used to make publicSale function uncallable
    function pausePublicSale() external onlyOwner() {
        publicSalePaused = true;
    }

    //used to buy tokens with eth
    function publicSale() external payable {
        uint256 bnb = msg.value;
        uint256 pulseToBeBought = bnb.mul(10**9) / tokenPrice;
        uint256 maxMintablePs = _percentageToAmountMintedToken(10);
        require(
            publicSalePaused == false,
            "Public sale: public sale is paused or it has stopped"
        );
        require(
            publicSaleMintedTokens + pulseToBeBought <= maxMintablePs,
            "Public sale: you need to buy less Pulse"
        );
        pulseToken.mint(_msgSender(), pulseToBeBought);
        publicSaleMintedTokens = publicSaleMintedTokens.add(pulseToBeBought);
    }

    //used to redeem a specific amount of tokens after a period of months established below
    //if the max mintable amount of tokens is not claimed at the specified time, the remaining
    //amount will be able to the next reward so the owner does not need to claim all the tokens in one trance
    function periodicMint(uint256 amountToBeMinted) external onlyOwner() {
        require(
            amountToBeMinted > 0,
            "Periodic mint: amount to be minted should be greater than 0"
        );
        uint256 month = 30 days;
        //stores the max amount of tokens that the owner can mint now
        uint256 canMint = 0;
        //used to store the max amount of tokens to be minted, for each reward
        uint256 amountLimit = 0;

        //1: 5% after 6 months
        if (creationTime + month.mul(6) <= block.timestamp) {
            amountLimit = _percentageToAmountMintedToken(5);
            //calculate the remaining amount that can be minted from this reward
            if (periodicMintedTokens < amountLimit) {
                canMint = canMint.add(amountLimit.sub(periodicMintedTokens));
            }
        }
        //2: 10% after 12 months
        if (creationTime + month.mul(12) <= block.timestamp) {
            amountLimit = _percentageToAmountMintedToken(10);
            //calculate the remaining amount that can be minted from this reward
            if (periodicMintedTokens < amountLimit) {
                canMint = canMint.add(amountLimit.sub(periodicMintedTokens));
            }
        }
        //3: 10% after 18 months
        if (creationTime + month.mul(18) <= block.timestamp) {
            amountLimit = _percentageToAmountMintedToken(10);
            //calculate the remaining amount that can be minted from this reward
            if (periodicMintedTokens < amountLimit) {
                canMint = canMint.add(amountLimit.sub(periodicMintedTokens));
            }
        }
        //4: 15% after 24 months
        if (creationTime + month.mul(24) <= block.timestamp) {
            amountLimit = _percentageToAmountMintedToken(15);
            //calculate the remaining amount that can be minted from this reward
            if (periodicMintedTokens < amountLimit) {
                canMint = canMint.add(amountLimit.sub(periodicMintedTokens));
            }
        }
        require(
            canMint >= amountToBeMinted,
            "Pulse: you need to mint less tokens"
        );
        pulseToken.mint(_msgSender(), amountToBeMinted);
        periodicMintedTokens = periodicMintedTokens.add(amountToBeMinted);
    }

    //returns the toal amount of minted tokens
    function getMintedTokensTotal() external view returns (uint256) {
        uint256 totalMinted = publicSaleMintedTokens.add(periodicMintedTokens);
        if (hasOwnerMintedHalf)
            totalMinted = totalMinted.add(_percentageToAmountMintedToken(50));
        return totalMinted;
    }

    receive() external payable {}

    //adds a token to the revive basket tokens array
    function addToken(address _tokenAddress, uint256 _tokenWeight)
        external
        onlyOwner
    {
        reviveBasketWeight = reviveBasketWeight.add(_tokenWeight);
        reviveBasketToken memory token = reviveBasketToken(
            _tokenAddress,
            _tokenWeight
        );
        reviveBasketTokens.push(token);
    }

    //removes a token from the revive basket tokens array
    function removeToken(address _tokenAddress) external onlyOwner {
        for (uint256 i = 0; i < reviveBasketTokens.length; i++) {
            if (reviveBasketTokens[i].tokenAddress == _tokenAddress) {
                reviveBasketWeight = reviveBasketWeight.sub(
                    reviveBasketTokens[i].weight
                );
                reviveBasketTokens[i] = reviveBasketTokens[
                    reviveBasketTokens.length - 1
                ];
                reviveBasketTokens.pop();
                break;
            }
        }
    }

    function getTokenWeight(address _tokenAddress)
        public
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < reviveBasketTokens.length; i++) {
            if (reviveBasketTokens[i].tokenAddress == _tokenAddress) {
                return reviveBasketTokens[i].weight;
            }
        }
        return 0;
    }

    //returns the amount of eth that can be used to buy a specific token based
    // on the total eth amount (totalBalance) and the token's weight 
    function _getEthAmountToBeUsed(uint256 totalBalance, uint256 tokenWeight)
        private
        view
        returns (uint256)
    {
        uint256 amount = (totalBalance / 100).mul(tokenWeight.mul(100)) / reviveBasketWeight;
        return amount;
    }

    //used to swap "_tokenAmount" of tokens of the specified token (_tokenAddress)
    // into eth and returns the resulted amount
    function _swapExactTokensForEth(uint256 _tokenAmount, address _tokenAddress)
        private
        returns (uint256)
    {
        uint256 initialBalance = address(this).balance;

        IERC20 tokenContract = IERC20(_tokenAddress);

        tokenContract.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            _tokenAmount
        );

        // generate the uniswap pair path of token -> BNB
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp + 7 days
        );

        return address(this).balance.sub(initialBalance);
    }

    //swap half of the "ethAmount" into the specified token and add liquidity to the WETH -> token
    //pool with the remaining half of the "ethAmount"
    function _buyToken(reviveBasketToken memory token, uint256 ethAmount)
        private
    {
        IERC20 tokenContract = IERC20(token.tokenAddress);

        // generate the uniswap pair path of WETH -> token
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = token.tokenAddress;

        //get pair address of the WETH -> token pair
        address pairAddress = factory.getPair(uniswapV2Router.WETH(), token.tokenAddress);

        //if pair don't exist
        if(pairAddress == address(0)) return;

        // capture the contract's current "token" balance.
        // this is so that we can capture exactly the amount of "token" that the
        // swap creates, and not make the liquidity event include any "token" that
        // has been manually sent to the contract
        uint256 tokenAmount = tokenContract.balanceOf(address(this));
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount / 2
        }(0, path, address(this), block.timestamp + 7 days);

        // how much "token" did we just swap into?
        tokenAmount = tokenContract.balanceOf(address(this)).sub(tokenAmount);
        tokenContract.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            tokenAmount
        );
       //adds liquidity to the WETH -> token
       uniswapV2Router.addLiquidityETH{value: ethAmount / 2}(
            token.tokenAddress,
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 7 days
        );
    }

    function handleReviveBasket(uint256 pulseAmount)
        public
        override
        returns (bool)
    {
        //swap all the received PULSE into eth
        uint256 ethAmount = _swapExactTokensForEth(pulseAmount, pulseTokenAddress);
        for (uint256 i = 0; i < reviveBasketTokens.length; i++) {
            _buyToken(
                reviveBasketTokens[i],
                _getEthAmountToBeUsed(ethAmount, reviveBasketTokens[i].weight)
            );
        }
        return true;
    }

    function _convertTokenLpsIntoEth(address _tokenAddress, uint256 _lpTokens)
        private
        returns (uint256)
    {

        address pairAddress = factory.getPair(uniswapV2Router.WETH(), _tokenAddress);

        if(pairAddress == address(0)) return 0;

        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        IERC20 token = IERC20(_tokenAddress);

        if(_lpTokens > pair.balanceOf(address(this))) {
            return 0;
        }

        //approve the router to use all the lp's of this contract
        pair.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            _lpTokens
        );

        //swap all the LP's into eth and PULSE
        // capture the contract's current eth and PULSE.
        // this is so that we can capture exactly the amount of eth that the
        // swap creates, and not make the liquidity event include any eth and pulse that
        // has been manually sent to the contract
        uint256 amountEth = address(this).balance;
        uint256 amountToken = token.balanceOf(address(this));

        uniswapV2Router.removeLiquidityETHSupportingFeeOnTransferTokens(
            _tokenAddress,
            _lpTokens,
            0,
            0,
            address(this),
            block.timestamp + 7 days
        );
        // how much PULSE did we just swap into?
        amountToken = token.balanceOf(address(this)).sub(amountToken);

        //swap the obtained PULSE tokens into eth
        _swapExactTokensForEth(amountToken, _tokenAddress);

        // how much ETH did we just swap into?
        amountEth = address(this).balance.sub(amountEth);
        return amountEth;
    }

    //used to swap "_lpTokens" amount of 
    function redeemLpTokens(address _tokenAddress, uint256 _lpTokens) external onlyOwner {
        address pairAddress = factory.getPair(uniswapV2Router.WETH(), _tokenAddress);
        if(pairAddress == address(0)) return;
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        require(pair.balanceOf(address(this)) >= _lpTokens, "Revive Basket: you don't have enough founds");
        
        uint256 amountEth = _convertTokenLpsIntoEth(_tokenAddress, _lpTokens);

        //generate the uniswap pair path of WETH -> PULSE
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = pulseTokenAddress;

        uint256 balance = pulseToken.balanceOf(address(this));
        
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountEth
        }(0, path, address(this), block.timestamp + 7 days);

        balance = pulseToken.balanceOf(address(this)).sub(balance);
        IToken token = IToken(pulseTokenAddress);
        token.deliver(balance);
    }

    function reedemLpTokensPulse() external onlyOwner override returns(uint256) {

        address ethPulsePairAddress = factory.getPair(uniswapV2Router.WETH(), pulseTokenAddress);

        //get contract interafce of the uniswapV2PairToken
        IUniswapV2Pair ethPulsePairContract = IUniswapV2Pair(ethPulsePairAddress);

        //approve the router to use all the LP's of this contract
        ethPulsePairContract.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            ethPulsePairContract.balanceOf(address(this))
        );

        //swap all the LP's into ETH and Pulse
        uint256 amountEth;
        uint256 amountPulse = pulseToken.balanceOf(address(this));
        amountEth = uniswapV2Router
        .removeLiquidityETHSupportingFeeOnTransferTokens(
            address(this),
            ethPulsePairContract.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 7 days
        );

        //generate the uniswap pair path of WETH -> PULSE
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        //converts all of the eth into PULSE tokens and transfers them to the owner
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountEth
        }(1, path, address(this), block.timestamp + 7 days);

        // how much ETH did we just swap into?
        amountPulse = pulseToken.balanceOf(address(this)).sub(amountPulse);  
        return amountPulse; 
    }
}
