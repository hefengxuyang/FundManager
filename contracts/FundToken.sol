// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import './owner/Operator.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract FundToken is ERC20Burnable, Operator {
    /**
     * @notice Constructs the BNB-BUSD LP Token ERC-20 contract.
     */
    constructor() public ERC20("BNB-BUSD LP Token", 'BLPT') {}

    function mint(address recipient, uint256 amount)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient);
        _mint(recipient, amount);
        uint256 balanceAfter = balanceOf(recipient);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
    {
        super.burnFrom(account, amount);
    }
}