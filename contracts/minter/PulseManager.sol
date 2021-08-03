// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.12;
import "./IPulseManager.sol";
import "../openzeppelin/contracts/token/IToken.sol";
import "../openzeppelin/contracts/libraries/Ownable.sol";
import "../openzeppelin/contracts/libraries/SafeMath.sol";
import "../openzeppelin/contracts/token/IERC20.sol";
import "../pancakeswap/interfaces/IPancakeRouter02.sol";
import "../pancakeswap/interfaces/IPancakeFactory.sol";
import "../pancakeswap/interfaces/IPancakePair.sol";
import "hardhat/console.sol";

contract PulseManager is IPulseManager, Ownable {
    using SafeMath for uint256;

    uint256 private creationTime = 0;
    uint256 private tokenPrice = 1;

    bool private publicSalePaused = true;
    uint256 private publicSaleMintedTokens = 0;

    uint256 private tokensMintedByOwnerFromHalf = 0;
    uint256 private periodicMintedTokens = 0;

    address private pulseTokenAddress;
    IERC20 private pulseToken = IERC20(0x00);
    IPancakeRouter02 private pancakeSwapRouter;
    IPancakeFactory private factory;
    mapping(address => bool) private isTokenInReviveBasket;

    address private pancakeSwapRouterAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;

    struct reviveBasketToken {
        address tokenAddress;
        uint256 weight;
    }

    reviveBasketToken[] public reviveBasketTokens;
    uint256 private reviveBasketWeight = 0;

    event SetTokenAddress(address indexed user, address _tokenAddress);
    event SetTokenPrice(address indexed user, uint256 _tokenPrice);
    event MintHalfByOwner(address indexed user, address _to, uint256 _amount);
    event InitPublicSale(address indexed user);
    event PausePublicSale(address indexed user);
    event PeriodicMint(address indexed user, uint256 _amountToBeMinted);
    event AddToken(address indexed user, address _tokenAddress, uint256 _tokenWeight);
    event RemoveToken(address indexed user, address _tokenAddress);
    event RedeemLpTokens(address indexed user, address _tokenAddress, uint256 _lpTokens);
    event RedeemLpTokensPulse(address indexed user, uint256 _lpTokens);
    event BurnRemainingBNB(address indexed user, uint256 _amount);
    event BurnRemainingPulse(address indexed user, uint256 _amount);

    constructor(address _pancakeSwapRouterAddress) public {
        creationTime = block.timestamp;
        pancakeSwapRouterAddress = _pancakeSwapRouterAddress;
        pancakeSwapRouter = IPancakeRouter02(
            _pancakeSwapRouterAddress
        );
        factory = IPancakeFactory(pancakeSwapRouter.factory());
    }

    //used to set the address of the PULSE token
    function setTokenAddress(address _tokenAddress) external onlyOwner {
        pulseToken = IERC20(_tokenAddress);
        pulseTokenAddress = _tokenAddress;
        emit SetTokenAddress(_msgSender(), _tokenAddress);
    }

    //used to set the price of the PULSE token
    function setTokenPrice(uint256 _tokenPrice) external onlyOwner {
        tokenPrice = _tokenPrice;
        emit SetTokenPrice(_msgSender(), _tokenPrice);
    }

    //converts percentage to amount from 1000000000
    function _percentageToAmountMintedToken(uint256 _percentage)
        private
        pure
        returns (uint256)
    {
        //maximum supply divided by 100
        uint256 maximumSupply = 10**16;
        maximumSupply = maximumSupply.mul(_percentage);
        return maximumSupply;
    }

    //used to mint half of the total tokens to the owner
    function mintHalfByOwner(address _to, uint256 _amount) external onlyOwner {
        require(
            _percentageToAmountMintedToken(50) >= tokensMintedByOwnerFromHalf.add(_amount),
            "Mint: you can mint a maximum amount of 50% from total amount of tokens"
        );
        pulseToken.mint(_to, _amount);
        tokensMintedByOwnerFromHalf = tokensMintedByOwnerFromHalf.add(_amount);
        emit MintHalfByOwner(_msgSender(), _to, _amount);
    }

    //used to make publicSale function callable
    function initPublicSale() external onlyOwner {
        publicSalePaused = false;
        emit InitPublicSale(_msgSender());
    }

    //used to make publicSale function uncallable
    function pausePublicSale() external onlyOwner {
        publicSalePaused = true;
        emit PausePublicSale(_msgSender());
    }

    //used to buy tokens with BNB
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
        payable(owner()).transfer(msg.value);
        pulseToken.mint(_msgSender(), pulseToBeBought);
        publicSaleMintedTokens = publicSaleMintedTokens.add(pulseToBeBought);
    }

    //used to redeem a specific amount of tokens after a period of months established below
    //if the max mintable amount of tokens is not claimed at the specified time, the remaining
    //amount will be able to the next reward so the owner does not need to claim all the tokens in one trance
    function periodicMint(uint256 _amountToBeMinted) external onlyOwner {
        require(
            _amountToBeMinted > 0,
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
            canMint >= _amountToBeMinted,
            "Pulse: you need to mint less tokens"
        );
        pulseToken.mint(_msgSender(), _amountToBeMinted);
        periodicMintedTokens = periodicMintedTokens.add(_amountToBeMinted);
        
        emit PeriodicMint(_msgSender(), _amountToBeMinted);
    }

    //returns the toal amount of minted tokens
    function getMintedTokensTotal() external view returns (uint256) {
        uint256 totalMinted = publicSaleMintedTokens.add(periodicMintedTokens);
        totalMinted = totalMinted.add(tokensMintedByOwnerFromHalf);
        return totalMinted;
    }

    receive() external payable {}

    //adds a token to the revive basket tokens array
    function addToken(address _tokenAddress, uint256 _tokenWeight)
        external
        onlyOwner
    {
        require(isTokenInReviveBasket[_tokenAddress] == false, "Token is already in revive basket!");
        reviveBasketWeight = reviveBasketWeight.add(_tokenWeight);
        reviveBasketToken memory token = reviveBasketToken(
            _tokenAddress,
            _tokenWeight
        );
        reviveBasketTokens.push(token);
        isTokenInReviveBasket[_tokenAddress] = true;
        emit AddToken(_msgSender(), _tokenAddress, _tokenWeight);
    }

    //removes a token from the revive basket tokens array
    function removeToken(address _tokenAddress) external onlyOwner {
        for (uint256 i = 0; i < reviveBasketTokens.length; i++) {
            if (reviveBasketTokens[i].tokenAddress == _tokenAddress) {
                reviveBasketWeight = reviveBasketWeight.sub(
                    reviveBasketTokens[i].weight
                );
                reviveBasketTokens[i] = reviveBasketTokens[
                    reviveBasketTokens.length.sub(1)
                ];
                reviveBasketTokens.pop();
                isTokenInReviveBasket[_tokenAddress] = false;
                emit RemoveToken(_msgSender(), _tokenAddress);
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

    //returns the amount of bnb that can be used to buy a specific token based
    // on the total bnb amount (_totalBalance) and the token's weight (_tokenWeight)
    function _getBnbAmountToBeUsed(uint256 _totalBalance, uint256 _tokenWeight)
        private
        view
        returns (uint256)
    {
        uint256 amount = (_totalBalance).mul(_tokenWeight).div(reviveBasketWeight);
        return amount;
    }

    //used to swap "_tokenAmount" of tokens of the specified token (_tokenAddress)
    // into bnb and returns the resulted amount
    function _swapExactTokensForBnb(uint256 _tokenAmount, address _tokenAddress)
        private
        returns (uint256)
    {
        uint256 initialBalance = address(this).balance;

        IERC20 tokenContract = IERC20(_tokenAddress);

        tokenContract.approve(
            pancakeSwapRouterAddress,
            _tokenAmount
        );

        // generate the uniswap pair path of token -> bnb
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = pancakeSwapRouter.WETH();

        pancakeSwapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount of bnb
            path,
            address(this),
            10462302631
        );

        return address(this).balance.sub(initialBalance);
    }

    //swap half of the "_bnbAmount" into the specified token and add liquidity to the BNB -> token
    //pool with the remaining half of the "_bnbAmount"
    function _buyToken(reviveBasketToken memory _token, uint256 _bnbAmount)
        private
    {
        IERC20 tokenContract = IERC20(_token.tokenAddress);

        // generate the uniswap pair path of BNB -> token
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
        path[1] = _token.tokenAddress;

        //get pair address of the BNB -> token pair
        address pairAddress = factory.getPair(pancakeSwapRouter.WETH(), _token.tokenAddress);

        //if pair don't exist
        if(pairAddress == address(0)) return;

        // capture the contract's current "token" balance.
        // this is so that we can capture exactly the amount of "token" that the
        // swap creates, and not make the liquidity event include any "token" that
        // has been manually sent to the contract
        uint256 tokenAmount = tokenContract.balanceOf(address(this));
        pancakeSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: _bnbAmount / 2
        }(0, path, address(this), 10462302631);
        // how much "token" did we just swap into?
        tokenAmount = tokenContract.balanceOf(address(this)).sub(tokenAmount);

        tokenContract.approve(
            pancakeSwapRouterAddress,
            tokenAmount
        );
       //adds liquidity to the BNB -> token
       pancakeSwapRouter.addLiquidityETH{value: _bnbAmount / 2}(
            _token.tokenAddress,
            tokenAmount,
            0,
            0,
            address(this),
            10462302631
        );
    }

    function handleReviveBasket(uint256 _pulseAmount)
        public
        override
        returns (bool)
    {
        require(_msgSender() == pulseTokenAddress, "Revive basket: this function can only be called by PULSE Token Contract");
        //swap all the received PULSE into BNB
        uint256 bnbAmount = _swapExactTokensForBnb(_pulseAmount, pulseTokenAddress);
        for (uint256 i = 0; i < reviveBasketTokens.length; i++) {
            _buyToken(
                reviveBasketTokens[i],
                _getBnbAmountToBeUsed(bnbAmount, reviveBasketTokens[i].weight)
            );
        }
        return true;
    }

    function _convertTokenLpsIntoBnb(address _tokenAddress, uint256 _lpTokens)
        private
        returns (uint256)
    {

        address pairAddress = factory.getPair(pancakeSwapRouter.WETH(), _tokenAddress);

        if(pairAddress == address(0)) return 0;

        IPancakePair pair = IPancakePair(pairAddress);

        IERC20 token = IERC20(_tokenAddress);

        if(_lpTokens > pair.balanceOf(address(this))) {
            return 0;
        }

        //approve the router to use all the lp's of this contract
        pair.approve(
            pancakeSwapRouterAddress,
            _lpTokens
        );

        //swap all the LP's into BNB and PULSE
        // capture the contract's current BNB and PULSE.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB and pulse that
        // has been manually sent to the contract
        uint256 amountBnb = address(this).balance;
        uint256 amountToken = token.balanceOf(address(this));
        
        pancakeSwapRouter.removeLiquidityETHSupportingFeeOnTransferTokens(
            _tokenAddress,
            _lpTokens,
            0,
            0,
            address(this),
            10462302631
        );
        // how much PULSE did we just swap into?
        amountToken = token.balanceOf(address(this)).sub(amountToken);

        //swap the obtained PULSE tokens into BNB
        _swapExactTokensForBnb(amountToken, _tokenAddress);

        // how much BNB did we just swap into?
        amountBnb = address(this).balance.sub(amountBnb);
        return amountBnb;
    }

    //used to swap "_lpTokens" amount of 
    function redeemLpTokens(address _tokenAddress, uint256 _lpTokens) external onlyOwner {
        address pairAddress = factory.getPair(pancakeSwapRouter.WETH(), _tokenAddress);
        if(pairAddress == address(0)) return;
        IPancakePair pair = IPancakePair(pairAddress);
        require(pair.balanceOf(address(this)) >= _lpTokens, "Revive Basket: you don't have enough founds");
        uint256 amountBnb = _convertTokenLpsIntoBnb(_tokenAddress, _lpTokens);

        //generate the uniswap pair path of BNB -> PULSE
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
        path[1] = pulseTokenAddress;

        uint256 balance = pulseToken.balanceOf(address(this));
        
        pancakeSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountBnb
        }(0, path, address(this), 10462302631);

        balance = pulseToken.balanceOf(address(this)).sub(balance);
        IToken token = IToken(pulseTokenAddress);
        token.deliver(balance);

        emit RedeemLpTokens(_msgSender(), _tokenAddress, _lpTokens);
    }

    function redeemLpTokensPulse(uint256 _lpTokens) external onlyOwner returns(uint256) {
        
        address pairAddress = factory.getPair(pancakeSwapRouter.WETH(), pulseTokenAddress);
        if(pairAddress == address(0)) return 0;

        //get contract interafce of the pancakeSwapPairToken
        IPancakePair  bnbPulsePairContract = IPancakePair(pairAddress);

        //approve the router to use all the LP's of this contract
        bnbPulsePairContract.approve(
            pancakeSwapRouterAddress,
            _lpTokens
        );

        //swap all the LP's into BNB and PULSE
        uint256 amountBnb;
        uint256 amountPulse = pulseToken.balanceOf(address(this));
        amountBnb = pancakeSwapRouter
        .removeLiquidityETHSupportingFeeOnTransferTokens(
            pulseTokenAddress,
            _lpTokens,
            0,
            0,
            address(this),
            block.timestamp + 100 days
        );
        //generate the uniswap pair path of BNB -> PULSE
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
        path[1] = pulseTokenAddress;

        //converts all of the BNB into PULSE tokens and transfers them to the owner
        pancakeSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountBnb
        }(0, path, address(this), 10462302631);

        // how much BNB did we just swap into?
        amountPulse = pulseToken.balanceOf(address(this)).sub(amountPulse);  
        
        IToken pulse = IToken(pulseTokenAddress);

        pulse.burn(amountPulse);

        emit RedeemLpTokensPulse(_msgSender(), _lpTokens);
    }

    function burnRemainingEth() external onlyOwner {
         //generate the uniswap pair path of BNB -> PULSE
        address[] memory path = new address[](2);
        path[0] = pancakeSwapRouter.WETH();
        path[1] = pulseTokenAddress;

        uint256 balance = pulseToken.balanceOf(address(this));
        uint256 bnbAmount = address(this).balance;

        pancakeSwapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: bnbAmount
        }(0, path, address(this), 10462302631);

        balance = pulseToken.balanceOf(address(this)).sub(balance);

        IToken pulse = IToken(pulseTokenAddress);
        pulse.burn(balance);
        emit BurnRemainingBNB(_msgSender(), bnbAmount);
    }

    function burnRemainingPulse() external onlyOwner { 
        IToken pulse = IToken(pulseTokenAddress);
        uint256 pulseAmount = pulseToken.balanceOf(address(this));
        pulse.burn(pulseAmount);
        emit BurnRemainingPulse(_msgSender(), pulseAmount);
    }
}
