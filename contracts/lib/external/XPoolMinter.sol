// SPDX-License-Identifier: MIT
// pragma solidity ^0.6.0;
pragma solidity ^0.5.17;

contract XPoolMinter {

    function approve(address _erc20Contract, uint256 _amount) external;
    
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function reward(uint256 _pid) external;

    function getBalance(address _erc20Contract) external view;

    function getReward(uint256 _pid, address _user) external view returns (uint256, uint256);
}
