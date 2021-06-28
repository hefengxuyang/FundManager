// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

abstract contract YPoolMinter {

    function approve(address _erc20Contract, uint256 _amount) external virtual;
    
    function deposit(uint256 _pid, uint256 _amount) external virtual;

    function withdraw(uint256 _pid, uint256 _amount) external virtual;

    function reward(uint256 _pid) external virtual;

    function getBalance(address _erc20Contract) external view virtual;

    function getReward(uint256 _pid, address _user) external view virtual returns (uint256, uint256);
}
