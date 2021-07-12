// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../external/BakeryMaster.sol";

/**
 * @title BakeryController
 * @author yang
 * @dev This library handles deposits to and withdrawals from X liquidity pools.
 */
library BakeryController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address constant private MINT_POOL_CONTRACT = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
    BakeryMaster constant private bakeryMaster = BakeryMaster(MINT_POOL_CONTRACT);

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

    function deposit(address _pair, uint256 _amount) external {
        bakeryMaster.deposit(_pair, _amount);
    }

    function withdraw(address _pair, uint256 _amount) external {
        bakeryMaster.withdraw(_pair, _amount);
    }

    function emergencyWithdraw(address _pair) external {
        bakeryMaster.emergencyWithdraw(_pair);
    }

    function getReward(address _pair, address _user) external view returns (uint256) {
        bakeryMaster.pendingBake(_pair, _user);
    }

    function getPrincipal(address _pair, address _user) external view returns (uint256) {
        bakeryMaster.poolUserInfoMap(_pair, _user);
    }
}
