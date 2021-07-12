// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./lib/pools/BakeryController.sol";
import "./lib/pools/PancakeController.sol";
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
        if (pool == LiquidityPool.XPool) BakeryController.approve(_erc20Contract, _amount);
        else if (pool == LiquidityPool.YPool) PancakeController.approve(_erc20Contract, _amount);
        else revert("Invalid pool index.");
        emit ApproveToPool(_erc20Contract, _amount);
    }

    // 管理员操作的存储
    function depositToPool(address _erc20Contract, uint256 _amount) external onlyRebalancer {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) BakeryController.deposit(_erc20Contract, _amount);
        else if (pool == LiquidityPool.YPool) PancakeController.deposit(pid, _amount);
        else revert("Invalid pool index.");
        emit DepositToPool(_erc20Contract, _amount);
    }

    // 管理员操作的提现
    function withdrawFromPool(address _erc20Contract, uint256 _amount) external onlyRebalancer {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) BakeryController.withdraw(_erc20Contract, _amount);
        else if (pool == LiquidityPool.YPool) PancakeController.withdraw(pid, _amount);
        else revert("Invalid pool index.");
        emit WithdrawFromPool(_erc20Contract, _amount);
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
        return IERC20(_erc20Contract).balanceOf(address(this));
    }

    // 查询待领取的奖励金额
    function getPoolReward(address _erc20Contract) public view returns (uint256) {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) return BakeryController.getReward(_erc20Contract, address(this));
        else if (pool == LiquidityPool.YPool) return PancakeController.getReward(pid, address(this));
        else revert("Invalid pool index.");
    }

    // 查询已存入挖矿的流动性代币本金数量
    function getPoolPrincipal(address _erc20Contract) public view returns (uint256) {
        require(_erc20Contract != address(0), "Invalid LP contract.");
        LiquidityPool pool = contractPools[_erc20Contract];
        uint256 pid = contractPids[_erc20Contract];
        if (pool == LiquidityPool.XPool) return BakeryController.getPrincipal(_erc20Contract, address(this));
        else if (pool == LiquidityPool.YPool) return PancakeController.getPrincipal(pid, address(this));
        else revert("Invalid pool index.");
    }

    // 查询已投资和未投资的流动性代币的占比(优化：结果除以最大公约数)
    function getAvailableProportion() public view returns (uint256, uint256) {
        uint256 poolUsedAmount = 0;
        uint256 poolReservedAmount = 0;

        uint256 xPoolUsedAmount = BakeryController.getPrincipal(X_POOL_CONTRACT, address(this));
        uint256 yPoolUsedAmount = PancakeController.getPrincipal(contractPids[Y_POOL_CONTRACT], address(this));
        poolUsedAmount = poolUsedAmount.add(xPoolUsedAmount);
        poolUsedAmount = poolUsedAmount.add(yPoolUsedAmount);

        uint256 xPoolReservedAmount = getPoolBalance(X_POOL_CONTRACT);
        uint256 yPoolReservedAmount = getPoolBalance(Y_POOL_CONTRACT);
        poolReservedAmount = poolReservedAmount.add(xPoolReservedAmount);
        poolReservedAmount = poolReservedAmount.add(yPoolReservedAmount);

        return (poolUsedAmount, poolReservedAmount);
    }

    // 查询已投资的各个池的投资占比(优化：结果除以最大公约数)
    function getPoolProportion() public view returns (uint256[] memory) {
        uint256 xPoolUsedAmount = BakeryController.getPrincipal(X_POOL_CONTRACT, address(this));
        uint256 yPoolUsedAmount = PancakeController.getPrincipal(contractPids[Y_POOL_CONTRACT], address(this));
        uint256[] memory poolUsedAmounts = new uint256[](2);
        poolUsedAmounts[0] = xPoolUsedAmount;
        poolUsedAmounts[1] = yPoolUsedAmount;
        return poolUsedAmounts;
    }
}
