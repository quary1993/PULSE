pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

interface IToken {

    //used to deliver a specific amount of tokens to the all balance holders
    function deliver(uint256 tAmount) external;

    //returns the number of decimals that the token has
    function decimals() external view returns(uint8);

    function burn(uint256 tokenAmount) external;
}