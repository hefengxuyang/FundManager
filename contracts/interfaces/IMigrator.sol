// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IMigrator {
    function migrate(address, address, address, address, uint256, uint256) external returns (uint256, uint256, uint256);
}