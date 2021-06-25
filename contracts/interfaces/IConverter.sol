// SPDX-License-Identifier: MIT
// pragma solidity >=0.6.0;
pragma solidity >=0.5.17;

interface IConverter {
    function convert(address) external returns (uint256);
}
