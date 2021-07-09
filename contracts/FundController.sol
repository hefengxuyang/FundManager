// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./lib/pools/XPoolController.sol";
import "./lib/pools/YPoolController.sol";
import "./interfaces/IMigrator.sol";

/**
 * @title Fund Controller
 * @author yang
 * @notice This contract handles deposits to and withdrawals from the liquidity pools.
 * 1、 管理员管理，合约版本升级配置
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

    // mapping(address => address) public vaults;      // 机枪池
    // mapping(address => address) public strategies;  // 策略
    // mapping(address => mapping(address => bool)) public approvedStrategies; // 策略是否 approved 验证器

    enum LiquidityPool { XPool, YPool }
    mapping(address => LiquidityPool) private contractPools;   // 挖矿流动性合约池和 LiquidityPool 的映射关系
    mapping(address => uint256) private contractPids;          // 挖矿流动性合约池和 pid 的映射关系
    mapping(address => address) private contractMigrateFactorys;          // 挖矿流动性合约池和 pid 的映射关系

    address constant private X_POOL_CONTRACT = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
    address constant private Y_POOL_CONTRACT = 0xe2f2a5C287993345a840Db3B0845fbC70f5935a5;

    event FundGovernanceSet(address newAddress);
    event FundRebalancerSet(address newAddress);
    event FundMigratorSet(address newAddress);

    event ApproveToPool(address erc20Contract, uint256 amount);
    event DepositToPool(address erc20Contract, uint256 amount);
    event WithdrawFromPool(address erc20Contract, uint256 amount);
    event RewardFromPool(address erc20Contract);
    event Rebalance(uint256 oldLiquity, uint256 newLiquity);

    constructor(address _migrator) public {
        governance = msg.sender;
        rebalancer = msg.sender;
        migrator = _migrator;

        contractPools[X_POOL_CONTRACT] = LiquidityPool.XPool;
        contractPools[Y_POOL_CONTRACT] = LiquidityPool.YPool;
        contractPids[X_POOL_CONTRACT] = 1;
        contractPids[Y_POOL_CONTRACT] = 1;

        // 测试合约，根据实际情况是否固定地址
        contractMigrateFactorys[X_POOL_CONTRACT] = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
        contractMigrateFactorys[Y_POOL_CONTRACT] = 0xe2f2a5C287993345a840Db3B0845fbC70f5935a5;
    }

    modifier onlyGovernance() {
        require(governance == msg.sender, "Caller is not the governance.");
        _;
    }

    modifier onlyRebalancer() {
        require(rebalancer == msg.sender, "Caller is not the rebalancer.");
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

    // 管理员操作的approve
    function approveToPool(address _erc20Contract, uint256 _amount) external onlyRebalancer {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        if (pool == LiquidityPool.XPool) XPoolController.approve(_erc20Contract, _amount);
        else if (pool == LiquidityPool.YPool) YPoolController.approve(_erc20Contract, _amount);
        else revert("Invalid pool index.");
        emit ApproveToPool(_erc20Contract, _amount);
    }

    // 管理员操作的存储
    function depositToPool(address _erc20Contract, uint256 _amount) external onlyRebalancer {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) XPoolController.deposit(pid, _amount);
        else if (pool == LiquidityPool.YPool) YPoolController.deposit(pid, _amount);
        else revert("Invalid pool index.");
        emit DepositToPool(_erc20Contract, _amount);
    }

    // 管理员操作的提现
    function withdrawFromPool(address _erc20Contract, uint256 _amount) external onlyRebalancer {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) XPoolController.withdraw(pid, _amount);
        else if (pool == LiquidityPool.YPool) YPoolController.withdraw(pid, _amount);
        else revert("Invalid pool index.");
        emit WithdrawFromPool(_erc20Contract, _amount);
    }

    // 单独提现流动性代币
    function rewardFromPool(address _erc20Contract) external onlyRebalancer {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) XPoolController.reward(pid);
        else if (pool == LiquidityPool.YPool) YPoolController.reward(pid);
        else revert("Invalid pool index.");
        emit RewardFromPool(_erc20Contract);
    }

    // 挖矿调仓
    function rebalance(address _oldLpContract, address _newLpContract, uint256 _liquidity, uint256 _deadline) external onlyRebalancer returns (uint256 newLiquidity) {
        require(_oldLpContract != address(0) || _newLpContract != address(0), "Invalid LP contract.");
        address oldFactory = contractMigrateFactorys[_oldLpContract];
        address newFactory = contractMigrateFactorys[_newLpContract];
        newLiquidity = IMigrator(migrator).migrate(oldFactory, newFactory, _oldLpContract, _newLpContract, _liquidity, _deadline);
        emit Rebalance(_liquidity, newLiquidity);
    }

    // 查询未投资的流动性代币的余额
    function getPoolBalance(address _erc20Contract) public view returns (uint256) {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        if (pool == LiquidityPool.XPool) return XPoolController.getBalance(_erc20Contract);
        else if (pool == LiquidityPool.YPool) return YPoolController.getBalance(_erc20Contract);
        else revert("Invalid pool index.");
    }

    // 查询已投资的奖励金额和存入挖矿的流动性代币数量
    function getPoolReward(address _erc20Contract) public view returns (uint256, uint256) {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) return XPoolController.getReward(pid);
        else if (pool == LiquidityPool.YPool) return YPoolController.getReward(pid);
        else revert("Invalid pool index.");
    }

    // 查询已投资和未投资的流动性代币的占比(优化：结果除以最大公约数)
    function getAvailableProportion() public view returns (uint256, uint256) {
        uint256 poolUsedAmount = 0;
        uint256 poolReservedAmount = 0;

        (, uint256 xPoolUsedAmount) = XPoolController.getReward(contractPids[X_POOL_CONTRACT]);
        (, uint256 yPoolUsedAmount) = YPoolController.getReward(contractPids[Y_POOL_CONTRACT]);
        poolUsedAmount = poolUsedAmount.add(xPoolUsedAmount);
        poolUsedAmount = poolUsedAmount.add(yPoolUsedAmount);

        uint256 xPoolReservedAmount = XPoolController.getBalance(X_POOL_CONTRACT);
        uint256 yPoolReservedAmount = YPoolController.getBalance(Y_POOL_CONTRACT);
        poolReservedAmount = poolReservedAmount.add(xPoolReservedAmount);
        poolReservedAmount = poolReservedAmount.add(yPoolReservedAmount);

        return (poolUsedAmount, poolReservedAmount);
    }

    // 查询已投资的各个池的投资占比(优化：结果除以最大公约数)
    function getPoolProportion() public view returns (uint256[] memory) {
        (, uint256 xPoolUsedAmount) = XPoolController.getReward(contractPids[X_POOL_CONTRACT]);
        (, uint256 yPoolUsedAmount) = YPoolController.getReward(contractPids[Y_POOL_CONTRACT]);
        uint256[] memory poolUsedAmounts = new uint256[](2);
        poolUsedAmounts[0] = xPoolUsedAmount;
        poolUsedAmounts[1] = yPoolUsedAmount;
        return poolUsedAmounts;
    }
}
