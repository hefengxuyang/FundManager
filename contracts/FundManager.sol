// SPDX-License-Identifier: MIT
pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/drafts/SignedSafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "./FundController.sol";
import "./FundToken.sol";

/**
 * @title FundManager
 * @notice This contract is the primary contract for the minning pool.
 */
contract FundManager is Initializable, Ownable {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeERC20 for IERC20;

    bool public fundDisabled; // Boolean that, if true, disables the primary functionality of this FundManager.

    // 统计提供流动性的量的 erc20 合约
    address private _fundTokenContract; // Address of the FundToken.
    FundToken public fundToken; // Contract of the FundToken.

    // 流动性池的总操控合约
    address payable private _fundControllerContract; // Address of the FundController.
    FundController public fundController;   // Contract of the FundController.

    // 代理合约和旧管理合约，主要用于合约升级
    address private _fundProxyContract; // Address of the FundProxy.
    address private _authorizedFundManager;   // Old FundManager contract authorized to migrate its data to the new one.

    address[] private supportedLpTokenContracts;     // Array of the supported lp token contracts
    mapping(address => address) private rewardTokenContracts;   // map of reward token by mined lp token contract
    
    // 提现手续费设置（暂不考虑手续费存储手续费）
    uint256 private _withdrawalFeeRate;    // The current withdrawal fee rate (scaled by 1e18).
    address private _withdrawalFeeMasterBeneficiary;    // The master beneficiary of withdrawal fees; i.e., the recipient of all withdrawal fees.

    // 事件 event 
    event FundManagerUpgraded(address newContract); // Emitted when FundManager is upgraded.
    event FundControllerSet(address newContract);   // Emitted when the FundController of the FundManager is set or upgraded.
    event FundTokenSet(address newContract);    // Emitted when the FundToken of the FundManager is set.
    event FundProxySet(address newContract);    // Emitted when the FundProxy of the FundManager is set.
    event FundDisabled();   // Emitted when the primary functionality of this FundManager contract has been disabled.
    event FundEnabled();    // Emitted when the primary functionality of this FundManager contract has been enabled.
    event Deposit(address indexed sender, address indexed payee, uint256 amount);    // Emitted when funds have been deposited to Controller.
    event Withdrawal(address indexed sender, address indexed payee, uint256 amount);  // Emitted when funds have been withdrawn from Controller.


    modifier onlyProxy() {  // Throws if called by any account other than the FundProxy.
        require(_fundProxyContract == msg.sender, "Caller is not the FundProxy.");
        _;
    }

    modifier fundEnabled() {    // Throws if fund is disabled.
        require(!fundDisabled, "This fund manager contract is disabled. This may be due to an upgrade.");
        _;
    }

    // 合约初始化
    function initialize() public initializer {
        // Initialize base contracts
        Ownable.initialize(msg.sender);
        
        // TODO: LP代币入池初始化
        supportedLpTokenContracts.push(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);
        supportedLpTokenContracts.push(0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);
        rewardTokenContracts[0x398eC7346DcD622eDc5ae82352F02bE94C62d119] = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
        rewardTokenContracts[0xe2f2a5C287993345a840Db3B0845fbC70f5935a5] = 0xe2f2a5C287993345a840Db3B0845fbC70f5935a5;
    }

    /* ============ 升级 FundManager 合约配置 ============ */
    // 设置认证过的旧版本 FundManager 合约
    function setAuthorizeFundManager(address newAuthorizedFundManager) external onlyOwner {
        require(newAuthorizedFundManager != address(0), "new authorizeFundManager cannot be the zero address.");
        _authorizedFundManager = newAuthorizedFundManager;
    }

    // 升级新版本的 FundManager 合约
    function upgradeFundManager(address newFundManager) external onlyOwner {
        require(fundDisabled, "This fund manager contract must be disabled before it can be upgraded.");
        require(newFundManager != address(0), "new FundManager cannot be the zero address.");
        require(_authorizedFundManager != address(0) && msg.sender == _authorizedFundManager, "Caller is not an authorized source.");
        
        FundManager(newFundManager).setWithdrawalFeeRate(FundManager(_authorizedFundManager).getWithdrawalFeeRate());
        FundManager(newFundManager).setWithdrawalFeeMasterBeneficiary(FundManager(_authorizedFundManager).getWithdrawalFeeMasterBeneficiary());
        emit FundManagerUpgraded(newFundManager);
    }

    // 设置本合约的代理合约，主要用于合约升级
    function setFundProxy(address newContract) external onlyOwner {
        _fundProxyContract = newContract;
        emit FundProxySet(newContract);
    }

    // 设置本合约是否可用
    function setFundDisabled(bool disabled) external onlyOwner {
        require(disabled != fundDisabled, "No change to fund enabled/disabled status.");
        fundDisabled = disabled;
        if (disabled) 
            emit FundDisabled(); 
        else 
            emit FundEnabled();
    }

    /* ============ 关联合约配置 ============ */
    // 设置资金控制器合约地址 Controller （可接收主网币）
    function setFundController(address payable newContract) external onlyOwner {
        _fundControllerContract = newContract;
        fundController = FundController(_fundControllerContract);
        emit FundControllerSet(newContract);
    }

    // 设置流动性代币份额合约地址 FundToken，并设置其合约对象
    function setFundToken(address newContract) external onlyOwner {
        _fundTokenContract = newContract;
        fundToken = FundToken(_fundTokenContract);
        emit FundTokenSet(newContract);
    }

    /* ============ 提现手续费配置 ============ */
    // 设置提现手续费费率
    function setWithdrawalFeeRate(uint256 rate) external fundEnabled onlyOwner {
        require(rate != _withdrawalFeeRate, "This is already the current withdrawal fee rate.");
        require(rate <= 1e18, "The withdrawal fee rate cannot be greater than 100%.");
        _withdrawalFeeRate = rate;
    }

    // 查询提现手续费费率
    function getWithdrawalFeeRate() public view returns (uint256) {
        return _withdrawalFeeRate;
    }

    // 设置提现手续费的受益人
    function setWithdrawalFeeMasterBeneficiary(address beneficiary) external fundEnabled onlyOwner {
        require(beneficiary != address(0), "Master beneficiary cannot be the zero address.");
        _withdrawalFeeMasterBeneficiary = beneficiary;
    }

    // 查询提现手续费的受益人
    function getWithdrawalFeeMasterBeneficiary() public view returns (address) {
        return _withdrawalFeeMasterBeneficiary;
    }

    /* ============ 存储和提现的关键部分 ============ */
    // 存入流动性代币
    function depositTo(address to, address minerLpToken, uint256 amount) public fundEnabled {
        // TODO 输入流动性代币地址 minerLpToken，进行可支持的代币地址的验证
        // Input validation
        require(minerLpToken != address(0), "Invalid miner LP token.");
        require(amount > 0, "Deposit amount must be greater than 0.");

        // Update net deposits, transfer funds from msg.sender, mint BLPT, and emit event
        IERC20(minerLpToken).safeTransferFrom(msg.sender, _fundControllerContract, amount); // The user must approve the transfer of tokens beforehand
        require(fundToken.mint(to, amount), "Failed to mint fund tokens.");
        emit Deposit(msg.sender, to, amount);
    }

    // 调用者存入流动性代币（调用者用户需要提前 approve 对应的 amount）
    function deposit(address minerLpToken, uint256 amount) external {
        depositTo(msg.sender, minerLpToken, amount);
    }

    // 查询资金控制器合约 Controller 中对应的流动性代币的余额
    function getPoolBalance(address minerLpToken) internal view returns (uint256 poolBalance) {
        // TODO 1、fundController添加函数hasTokenInPool，判断池中是否有代币
        //      2、添加cache，临时存储balance的状态
        (, poolBalance) = fundController.getPoolReward(minerLpToken);
    }

    // 根据资金控制器合约 Controller 中的资金调用情况进行提现
    function withdrawFromPoolsIfNecessary(address minerLpToken, uint256 amount) internal {
        // Check contract balance of token and withdraw from pools if necessary
        uint256 contractBalance = IERC20(minerLpToken).balanceOf(_fundControllerContract);
        if (contractBalance >= amount) return; 

        uint256 poolBalance = getPoolBalance(minerLpToken);
        uint256 amountLeft = amount.sub(contractBalance);
        bool withdrawAll = amountLeft >= poolBalance;
        uint256 poolAmount = withdrawAll ? poolBalance : amountLeft;
        fundController.withdrawFromPool(minerLpToken, poolAmount);
    }

    // 按照流动性代币类别进行对应的提现操作
    // - from 调用者用户
    // - minerLpToken 挖矿的流动性代币合约
    // - lpAmount 流动性代币份额合约 fundToken 的数量
    // - rewardAmount 奖励代币数量
    function _withdrawFrom(address from, address minerLpToken, uint256 lpAmount, uint256 rewardAmount) internal fundEnabled returns (uint256) {
        // TODO 1、输入流动性代币地址 minerLpToken，进行可支持的代币地址的验证
        //      2、根据已经在挖矿池中的的代币所占比例进行均衡提现
        // Input validation
        require(minerLpToken != address(0), "Invalid currency code.");
        require(lpAmount > 0, "Withdrawal amount must be greater than 0.");

        // Withdraw from pools if necessary
        withdrawFromPoolsIfNecessary(minerLpToken, lpAmount);

        // Withdraw reward token from pool
        if (rewardAmount > 0){
            fundController.rewardFromPool(minerLpToken);
        }

        // Calculate withdrawal fee and amount after fee
        uint256 feeAmount = lpAmount.mul(_withdrawalFeeRate).div(1e18);
        uint256 amountAfterFee = lpAmount.sub(feeAmount);

        fundToken.fundManagerBurnFrom(from, lpAmount); // The user must approve the burning of tokens beforehand
        IERC20 lpToken = IERC20(minerLpToken);
        lpToken.safeTransferFrom(_fundControllerContract, msg.sender, amountAfterFee);
        lpToken.safeTransferFrom(_fundControllerContract, _withdrawalFeeMasterBeneficiary, feeAmount);
        if (rewardAmount > 0){
            IERC20 rewardToken = IERC20(rewardTokenContracts[minerLpToken]);
            rewardToken.safeTransferFrom(_fundControllerContract, msg.sender, rewardAmount);
        } 
        
        emit Withdrawal(from, msg.sender, lpAmount);

        // Return amount after fee
        return amountAfterFee;
    }

    // 根据资金控制器合约 Controller 中的持仓比例进行等比例的本金和收益提现
    function _withdrawFromPoolByProportion(address from, uint256 amount) internal fundEnabled returns (uint256[] memory) {
        // Input validation
        require(amount > 0, "Withdrawal amount must be greater than 0.");
        require(amount <= fundToken.balanceOf(from), "Your BLPT balance is less than the withdrawal amount.");

        // Proportion calculation supportedLpTokenContracts
        uint256[] memory poolLpAmounts = new uint256[](supportedLpTokenContracts.length);
        uint256[] memory poolRewardAmounts = new uint256[](supportedLpTokenContracts.length);
        uint256 totalPoolLpAmount = 0;
        for (uint256 i = 0; i < supportedLpTokenContracts.length; i++) {
            address curLpToken = supportedLpTokenContracts[i];
            (uint256 curRewardAmount, uint256 curLpAmount) = fundController.getPoolReward(curLpToken);

            // reward token amount
            address curRewardToken = rewardTokenContracts[curLpToken];
            curRewardAmount = curRewardAmount.add(IERC20(curRewardToken).balanceOf(_fundControllerContract));
            poolRewardAmounts[i] = curRewardAmount;

            // lp token amount
            curLpAmount = curLpAmount.add(fundController.getPoolBalance(curLpToken));
            poolLpAmounts[i] = curLpAmount;
            totalPoolLpAmount = totalPoolLpAmount.add(curLpAmount);
        }

        // validate if the total amount is zero
        require(totalPoolLpAmount > 0, "Total LP amount is empty.");

        // withdraw lp token and reward token
        uint256[] memory amountsAfterFees = new uint256[](supportedLpTokenContracts.length);
        for (uint256 i = 0; i < poolLpAmounts.length; i++) {
            uint256 curWithdrawLpAmount = amount.mul(poolLpAmounts[i]).div(totalPoolLpAmount);
            if (curWithdrawLpAmount == 0) continue;
            uint256 curWithdrawRewardAmount = poolRewardAmounts[i].mul(poolLpAmounts[i]).div(totalPoolLpAmount);
            amountsAfterFees[i] = _withdrawFrom(from, supportedLpTokenContracts[i], curWithdrawLpAmount, curWithdrawRewardAmount);
        }

        // Return amounts after fees
        return amountsAfterFees;
    }

    // 调用者根据自己拥有的流动性代币份额（fundToken）进行提现操作
    function withdraw(uint256 amount) external returns (uint256[] memory) {
        return _withdrawFromPoolByProportion(msg.sender, amount);
    }

    // 转出基金经理丢失的流动性代币，以防意外操作将资金转移到本合约
    function forwardLostFunds(address minerLpToken, address to) external onlyOwner returns (bool) {
        IERC20 token = IERC20(minerLpToken);
        uint256 balance = token.balanceOf(address(this));
        if (balance <= 0) return false;
        token.safeTransfer(to, balance);
        return true;
    }
}
