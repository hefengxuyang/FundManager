// SPDX-License-Identifier: MIT
// pragma solidity >=0.6.0;
pragma solidity >=0.5.17;

interface IMigrator {
    function migrate(address, address, uint256, uint256) external returns (uint256, uint256, uint256);
}