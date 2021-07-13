// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../external/PancakeMaster.sol";

/**
 * @title PancakeController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @dev This library handles deposits to and withdrawals from Aave liquidity pools.
 */
library PancakeController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address constant private MINT_POOL_CONTRACT = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
    PancakeMaster constant private pancakeMaster = PancakeMaster(MINT_POOL_CONTRACT);

    function getBalance(address _erc20Contract) external view returns (uint256) {
        return IERC20(_erc20Contract).balanceOf(address(this));
    }

    function approve(address _erc20Contract, uint256 _amount) external {
        IERC20 token = IERC20(_erc20Contract);
        uint256 allowance = token.allowance(address(this), MINT_POOL_CONTRACT);
        if (allowance == _amount) 
            return;

        if (_amount > 0 && allowance > 0) 
            token.safeApprove(MINT_POOL_CONTRACT, 0);

        token.safeApprove(MINT_POOL_CONTRACT, _amount);
        return;
    }

    function deposit(uint256 _pid, uint256 _amount) external {
        pancakeMaster.deposit(_pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) external {
        pancakeMaster.withdraw(_pid, _amount);
    }


    function emergencyWithdraw(uint256 _pid) external {
        pancakeMaster.emergencyWithdraw(_pid);
    }

    function getReward(uint256 _pid, address _user) external view returns (uint256) {
        pancakeMaster.pendingCake(_pid, _user);
    }

    function getPrincipal(uint256 _pid, address _user) external view returns (uint256) {
        (uint256 amount,) = pancakeMaster.userInfo(_pid, _user);
        return amount;
    }
}
