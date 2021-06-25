// SPDX-License-Identifier: MIT
pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../external/XPoolMinter.sol";

/**
 * @title XPoolController
 * @author yang
 * @dev This library handles deposits to and withdrawals from X liquidity pools.
 */
library XPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // 挖矿合约地址
    address constant private MINT_POOL_CONTRACT = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;

    // 挖矿合约实例对象
    XPoolMinter constant private _poolMinter = XPoolMinter(MINT_POOL_CONTRACT);

    // 挖矿池核心合约，主要用于 Approve
    address constant private MINT_POOL_CORE_CONTRACT = 0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3;

    function getBalance(address erc20Contract) external view returns (uint256) {
        return IERC20(erc20Contract).balanceOf(address(this));
    }

    function approve(address erc20Contract, uint256 amount) external {
        IERC20 token = IERC20(erc20Contract);
        uint256 allowance = token.allowance(address(this), MINT_POOL_CORE_CONTRACT);
        if (allowance == amount) 
            return;

        if (amount > 0 && allowance > 0) 
            token.safeApprove(MINT_POOL_CORE_CONTRACT, 0);

        token.safeApprove(MINT_POOL_CORE_CONTRACT, amount);
        return;
    }

    function deposit(uint256 pid, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _poolMinter.deposit(pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _poolMinter.withdraw(pid, amount);
    }

    function reward(uint256 pid) external {
        (uint256 rewardAmount,) =  _poolMinter.getReward(pid, msg.sender);
        if (rewardAmount == 0) return;
        _poolMinter.reward(pid);
    }

    function getReward(uint256 pid) external view returns (uint256, uint256) {
        _poolMinter.getReward(pid, msg.sender);
    }
}
