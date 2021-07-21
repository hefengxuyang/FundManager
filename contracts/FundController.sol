// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IMigrator.sol";
import "./interfaces/swap/ISwapV2Pair.sol";
import "./interfaces/master/IBakeryMaster.sol";
import "./interfaces/master/IMdexMaster.sol";
import "./interfaces/master/IPancakeMaster.sol";

/**
 * @title Fund Controller
 * @author yang
 * @notice This contract handles deposits to and withdrawals from the liquidity pools.
 * 1、 管理员管理
 * 2、 调仓管理
 * 3、 仓位查询
 */
contract FundController is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public governance;  // 治理（管理员）地址
    address public rebalancer;  // 策略调度员地址
    address public migrator;    // 迁移合约地址
    address public fundManager; // FundManager 管理合约地址

    address[] public supportedPairs;

    enum LiquidityPool { BakeryPool, MdexPool, PancakePool }
    mapping(address => LiquidityPool) public masterPools;   // 挖矿流动性合约池和 LiquidityPool 的映射关系
    mapping(address => address) public pairMasters;         // 挖矿流动性合约池中的交易对和 master 的映射关系
    mapping(address => uint256) public pairPids;            // 挖矿流动性合约池中的交易对和 pid 的映射关系
    mapping(address => bool) public PairTokenExists;        // 挖矿流动性合约池中的交易对和 是否存在(exist) 的映射关系

    address constant private BAKERY_MASTER_CONTRACT = 0xe17cF95Bd55F749ed56c76193AaafF99422b7487;
    // address constant private MDEX_MASTER_CONTRACT = 0xe2f2a5C287993345a840Db3B0845fbC70f5935a5;
    address constant private PANCAKE_MASTER_CONTRACT = 0x55fC7a3117107adcAE6C6a5b06E69b99C3fa4113;

    event FundGovernanceSet(address _governance);
    event FundRebalancerSet(address _rebalancer);
    event FundMigratorSet(address _migrator);
    event FundManagerSet(address _fundManager);

    event ApproveToPool(address _pair, uint256 _amount);
    event DepositToPool(address _pair, uint256 _amount);
    event WithdrawFromPool(address _pair, uint256 _amount);
    event Rebalance(uint256 _oldLiquity, uint256 _newLiquity);

    constructor() public {
        governance = msg.sender;
        rebalancer = msg.sender;

        addSupportedMaster(BAKERY_MASTER_CONTRACT, LiquidityPool.BakeryPool);
        // addSupportedMaster(MDEX_MASTER_CONTRACT, LiquidityPool.MdexPool);
        addSupportedMaster(PANCAKE_MASTER_CONTRACT, LiquidityPool.PancakePool);

        addSupportedPair(0x7BDa39b1B4cD4010836E7FC48cb6B817EEcFa94E, BAKERY_MASTER_CONTRACT, 0);
        // addSupportedPair(0x6B175474E89094C44Da98b954EedeAC495271d0F, MDEX_MASTER_CONTRACT, 1);
        addSupportedPair(0x1F53f4972AAc7985A784C84f739Be4d73FB6d14f, PANCAKE_MASTER_CONTRACT, 1);
    }

    function addSupportedMaster(address _master, LiquidityPool _pool) internal {
        masterPools[_master] = _pool;
    }

    function addSupportedPair(address _pair, address _master, uint256 _pid) internal {
        require(!PairTokenExists[_pair], "Liquity pair token has exists.");
        supportedPairs.push(_pair);
        PairTokenExists[_pair] = true;
        pairMasters[_pair] = _master;
        pairPids[_pair] = _pid;
    }

    modifier onlyGovernance() {
        require(governance == msg.sender, "Caller is not the governance.");
        _;
    }

    modifier onlyRebalancer() {
        require(rebalancer == msg.sender, "Caller is not the rebalancer.");
        _;
    }

    modifier onlyFundManager() {
        require(fundManager == msg.sender, "Caller is not the FundManager.");
        _;
    }

    function setGovernance(address _governance) external onlyOwner {
        governance = _governance;
        emit FundGovernanceSet(_governance);
    }

    function setRebalancer(address _rebalancer) external onlyGovernance {
        rebalancer = _rebalancer;
        emit FundRebalancerSet(_rebalancer);
    }

    function setMigrator(address _migrator) external onlyGovernance {
        migrator = _migrator;
        emit FundMigratorSet(_migrator);
    }

    function setFundManager(address _fundManager) external onlyGovernance {
        fundManager = _fundManager;
        emit FundManagerSet(_fundManager);
    }

    // 管理员操作的approve
    function approveToPool(address _pair, uint256 _amount) external onlyGovernance {
        require(_pair != address(0), "Invalid LP contract.");
        address master = pairMasters[_pair];
        require(master != address(0), "Invalid master contract.");
        IERC20 pairToken = IERC20(_pair);
        uint256 allowance = pairToken.allowance(address(this), master);
        if (allowance == _amount) 
            return;

        if (_amount > 0 && allowance > 0) 
            pairToken.approve(master, 0);

        pairToken.approve(master, _amount);
        emit ApproveToPool(_pair, _amount);
    }

    // 存储到挖矿池中(内部函数)
    function _depositToPool(address _pair, uint256 _amount) internal {
        require(_pair != address(0), "Invalid LP contract.");
        address master = pairMasters[_pair];
        LiquidityPool pool = masterPools[master];
        uint256 pid = pairPids[_pair];
        if (pool == LiquidityPool.BakeryPool) IBakeryMaster(master).deposit(_pair, _amount);
        else if (pool == LiquidityPool.MdexPool) IMdexMaster(master).deposit(pid, _amount);
        else if (pool == LiquidityPool.PancakePool) IPancakeMaster(master).deposit(pid, _amount);
        else revert("Invalid pool index.");
        emit DepositToPool(_pair, _amount);
    }

    // 调度员操作的存储
    function depositToPool(address _pair, uint256 _amount) external onlyRebalancer {
        _depositToPool(_pair, _amount);
    }

    // 管理员(FundManger)操作的存储
    function depositToPoolByManager(address _pair, uint256 _amount) external onlyFundManager {
        _depositToPool(_pair, _amount);
    }

    // 从挖矿池中提现(内部函数)
    function _withdrawFromPool(address _pair, uint256 _amount) internal {
        require(_pair != address(0), "Invalid LP contract.");
        address master = pairMasters[_pair];
        LiquidityPool pool = masterPools[master];
        uint256 pid = pairPids[_pair];
        if (pool == LiquidityPool.BakeryPool) IBakeryMaster(master).withdraw(_pair, _amount);
        else if (pool == LiquidityPool.MdexPool) IMdexMaster(master).withdraw(pid, _amount);
        else if (pool == LiquidityPool.PancakePool) IPancakeMaster(master).withdraw(pid, _amount);
        else revert("Invalid pool index.");
        emit WithdrawFromPool(_pair, _amount);
    }

    // 调度员操作的提现
    function withdrawFromPool(address _pair, uint256 _amount) external onlyRebalancer {
        _withdrawFromPool(_pair, _amount);
    }

    // 管理员(FundManger)操作的提现
    function withdrawFromPoolByManager(address _pair, uint256 _amount) external onlyFundManager {
        _withdrawFromPool(_pair, _amount);
    }

    // 挖矿调仓
    function rebalance(address _oldPair, address _newPair, uint256 _liquidity, uint256 _deadline) external onlyRebalancer returns (uint256 newLiquidity) {
        require(_oldPair != address(0) || _newPair != address(0), "Invalid LP contract.");
        address oldFactory = ISwapV2Pair(_oldPair).factory();
        address newFactory = ISwapV2Pair(_oldPair).factory();
        newLiquidity = IMigrator(migrator).migrate(oldFactory, newFactory, _oldPair, _newPair, _liquidity, _deadline);
        emit Rebalance(_liquidity, newLiquidity);
    }

    // 查询未投资的流动性代币的余额
    function getPoolBalance(address _token) public view returns (uint256) {
        require(_token != address(0), "Invalid ERC20 token contract.");
        return IERC20(_token).balanceOf(address(this));
    }

    // 查询待领取的奖励金额
    function getPoolReward(address _pair) public view returns (uint256) {
        require(_pair != address(0), "Invalid LP contract.");
        address master = pairMasters[_pair];
        LiquidityPool pool = masterPools[master];
        uint256 pid = pairPids[_pair];
        if (pool == LiquidityPool.BakeryPool) return IBakeryMaster(master).pendingBake(_pair, address(this));
        else if (pool == LiquidityPool.MdexPool) return IMdexMaster(master).pending(pid, address(this));
        else if (pool == LiquidityPool.PancakePool) return IPancakeMaster(master).pendingCake(pid, address(this));
        else revert("Invalid pool index.");
    }

    // 查询已存入挖矿的流动性代币本金数量
    function getPoolPrincipal(address _pair) public view returns (uint256 amount) {
        require(_pair != address(0), "Invalid LP contract.");
        address master = pairMasters[_pair];
        LiquidityPool pool = masterPools[master];
        uint256 pid = pairPids[_pair];
        if (pool == LiquidityPool.BakeryPool) (amount,) = IBakeryMaster(master).poolUserInfoMap(_pair, address(this));
        else if (pool == LiquidityPool.MdexPool) (amount,) = IMdexMaster(master).userInfo(pid, address(this));
        else if (pool == LiquidityPool.PancakePool) (amount,) = IPancakeMaster(master).userInfo(pid, address(this));
        else revert("Invalid pool index.");
    }

    // 转出基金经理丢失的流动性代币，以防意外操作将资金转移到本合约
    function forwardLostFunds(address _token, address _to) external onlyOwner returns (bool) {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance <= 0) return false;
        token.safeTransfer(_to, balance);
        return true;
    }
}
