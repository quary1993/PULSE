pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

interface IPulseManager {

    function handleReviveBasket(uint256 pulseAmount) external returns(bool);
    function swapAndLiquify(uint256 pulseAmount) external;

}