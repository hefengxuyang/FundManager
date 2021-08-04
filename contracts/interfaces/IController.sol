// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IController {
    function approveTo(address _token, address _receiver, uint256 _amount) external;

    function approveToMaster(address _pair, uint256 _amount) external;

    function approveToManager(address _token, uint256 _amount) external;

    function depositToPool(address _pair, uint256 _amount) external;

    function depositToPoolByManager(address _pair, uint256 _amount) external;

    function withdrawFromPool(address _pair, uint256 _amount) external;

    function withdrawFromPoolByManager(address _pair, uint256 _amount) external;

    function rebalance(address _oldPair, address _newPair, uint256 _liquidity, uint256 _deadline) external returns (uint256 newLiquidity);

    function getPoolBalance(address _token) external view returns (uint256);

    function getPoolReward(address _pair) external view returns (uint256);

    function getPoolPrincipal(address _pair) external view returns (uint256 amount);

    function forwardLostFunds(address _token, address _to) external returns (bool);
}
