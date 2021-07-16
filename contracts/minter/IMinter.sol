pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

interface IMinter {

    function handleReviveBasket(uint256 pulseAmount) external returns(bool);

    function reedemLpTokensPulse() external returns(uint256);

}