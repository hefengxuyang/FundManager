// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

abstract contract BakeryMaster {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public poolUserInfoMap;
    
    function deposit(address _pair, uint256 _amount) external virtual;

    function withdraw(address _pair, uint256 _amount) external virtual;

    function emergencyWithdraw(address _pair) external virtual;

    function pendingBake(address _pair, address _user) external view virtual returns (uint256);
}
