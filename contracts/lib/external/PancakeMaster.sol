// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

abstract contract PancakeMaster {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    
    function deposit(uint256 _pid, uint256 _amount) external virtual;

    function withdraw(uint256 _pid, uint256 _amount) external virtual;

    function emergencyWithdraw(uint256 _pid) external virtual;

    function pendingCake(uint256 _pid, address _user) external view virtual returns (uint256);
}
