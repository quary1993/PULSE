// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.12;

//uniswap contracts
import "../uniswap/core/IUniswapV2Factory.sol";
import "../uniswap/core/IUniswapV2Pair.sol";
import "../uniswap/periphery/IUniswapV2Router01.sol";
import "../uniswap/periphery/IUniswapV2Router02.sol";
import "../openzeppelin/contracts/token/IERC20.sol";
import "hardhat/console.sol";

contract PairCreator {
    IUniswapV2Router02 public immutable uniswapV2Router;
    IERC20 public immutable pulseToken;
    address pulseTokenAddress;

    constructor(address _pulseTokenAddress) public {
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        pulseTokenAddress = _pulseTokenAddress;
        pulseToken = IERC20(pulseTokenAddress);
    }

    receive() external payable {}

    function addLiquidity() public payable {
       uint256 amountToken;
       uint256 amountETH;
       uint256 liquidity;
       pulseToken.approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 20000);
       (amountToken, amountETH, liquidity) = uniswapV2Router.addLiquidityETH{value: msg.value}(pulseTokenAddress, 1000, 1, 1, msg.sender, 10429362993);
    }
}
