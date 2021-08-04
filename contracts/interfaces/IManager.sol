// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IManager {
    function deposit(address _pair, uint256 _amount) external;

    function withdraw(uint256 _amount) external returns (uint256[] memory);

    function forwardLostFunds(address _token, address _to) external returns (bool);
}
