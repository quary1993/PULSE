// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.12;
import "../openzeppelin/contracts/libraries/Ownable.sol";
import "../openzeppelin/contracts/libraries/SafeMath.sol";
import "../openzeppelin/contracts/token/IERC20.sol";
import "../uniswap/periphery/IUniswapV2Router02.sol";
import "hardhat/console.sol";

contract Minter is Ownable {
    using SafeMath for uint256;

    uint256 private creationTime = 0;
    bool private publicSalePaused = true;
    bool private hasOwnerMintedHalf = false;
    uint256 private publicSaleMintedTokens = 0;
    uint256 private periodicMintedTokens = 0;
    uint256 private tokenPrice = 1;
    address private pulseTokenAddress;
    IERC20 private pulseToken = IERC20(0x00);
    IUniswapV2Router02 private uniswapV2Router;

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
    }

    //used to set the address of the token which has the _mint function
    //params: _tokenAddress (address) - the address of the token which has the _mint function
    function setTokenAddress(address _tokenAddress) external {
        pulseToken = IERC20(_tokenAddress);
        pulseTokenAddress = _tokenAddress;
    }

    //used to set the price of the token which has the _mint function
    //params: _tokenPrice (uint256) - the price (with 18 decimals) of the token which has the _mint function
    function setTokenPrice(uint256 _tokenPrice) external {
        tokenPrice = _tokenPrice;
    }

    //converts percentage to amount from 1000000000
    //params: percentage (uint256) - the percentage that needs to be converted
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
    //params: to (address) - the address which will hold resulting tokens
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
    //params: msg.value - the amount of eth used to buy tokens
    //req: - public sale should not be on pause
    //     - the amount minted by public sale cannot exceed 10% of the amount of mintable tokens
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
    //params: amountToBeMinted (uint256) - the amount the owner wants to mint
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

    function _getTokenWeight(address _tokenAddress)
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

    function _getAmountToBeBought(uint256 totalBalance, uint256 tokenWeight)
        private
        view
        returns (uint256)
    {
        return
            (totalBalance / 100).mul(tokenWeight.mul(100)) / reviveBasketWeight;
    }

    function _swapExactTokensForEth(uint256 tokenAmount)
        private
        returns (uint256)
    {
        uint256 initialBalance = address(this).balance;

        pulseToken.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            tokenAmount
        );

        // generate the uniswap pair path of token -> BNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp + 7 days
        );

        return address(this).balance.sub(initialBalance);
    }

    function _buyToken(reviveBasketToken memory token, uint256 ethAmount)
        private
    {
        IERC20 tokenContract = IERC20(token.tokenAddress);

        // generate the uniswap pair path of token -> BNB
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = token.tokenAddress;

        uint256[] memory amountsOut = uniswapV2Router.getAmountsOut(
            ethAmount / 2,
            path
        );

        //return aici
        require(amountsOut[1] > 0, "Revive Basket: insufficient liquidity");

        uint256 tokenAmount = tokenContract.balanceOf(address(this));
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount / 2
        }(0, path, address(this), block.timestamp + 7 days);
        tokenAmount = tokenContract.balanceOf(address(this)).sub(tokenAmount);

        tokenContract.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            tokenAmount
        );

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
        external
        onlyOwner
        returns (bool)
    {
        uint256 ethAmount = _swapExactTokensForEth(pulseAmount);
        for (uint256 i = 0; i < reviveBasketTokens.length; i++) {
            _buyToken(
                reviveBasketTokens[i],
                _getAmountToBeBought(ethAmount, reviveBasketTokens[i].weight)
            );
        }
        return true;
    }

    function convertTokenLpsIntoEth(address _tokenAddress)
        private
        returns (uint256)
    {
        IERC20 tokenContract = IERC20(_tokenAddress);

        //approve the router to use all the LP's of this contract
        tokenContract.approve(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            tokenContract.balanceOf(address(this))
        );

        //switch all the LP's into ETH and Pulse
        uint256 amountEth = address(this).balance;
        uint256 amountToken = tokenContract.balanceOf(address(this));
        uniswapV2Router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(this),
            tokenContract.balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 7 days
        );
        amountToken = tokenContract.balanceOf(address(this)).sub(amountToken);

        //generate the uniswap pair path of WETH -> PULSE
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = uniswapV2Router.WETH();

        //converts all of the eth into PULSE tokens and transfers them to the owner
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToken,
            0,
            path,
            address(this),
            block.timestamp + 7 days
        );

        amountEth = address(this).balance.sub(amountEth);
        return amountEth;
    }

    function redeemLpTokens(address _tokenAddress) external onlyOwner {
        uint256 amountEth = convertTokenLpsIntoEth(_tokenAddress);

        //generate the uniswap pair path of WETH -> PULSE
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = uniswapV2Router.WETH();

        uint256 balance = pulseToken.balanceOf(address(this));

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountEth
        }(0, path, address(this), block.timestamp + 7 days);

        balance = pulseToken.balanceOf(address(this)).sub(balance);

        (bool success, ) = pulseTokenAddress.call(
            abi.encodeWithSignature("deliver(uint256)", balance)
        );
        require(
            success,
            "Revive Baksed: an error ocurred when delivering the obtained PULSE"
        );
    }
}
