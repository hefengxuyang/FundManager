# 合约接口

## 调用接口信息

### FundManager（用户调用）

```js
// 功能：调用者存入流动性代币进行智能挖矿
// 函数参数：
//  - _pair 流动性代币，只能使用 supportedPairTokenContracts 支持的流动性代币
//  - _amount 代币数量，默认单位 10^18
// 注意事项：调用 depisit 之前，必须调用流动性交易对 _pair 合约的 approve 函数，并通过对 FundManager 合约地址允许对应的数量，否则没法存储
function deposit(address _pair, uint256 _amount) external;

// 功能：调用者根据自己拥有的流动性份额代币（FundToken）进行提现操作
// 函数参数：
//  - _amount 流动性份额代币的数量
//    - 0 表示仅提现挖矿的代币收益，不撤回流动性代币挖矿
//    - Number 需要少于等于 FundToken 份额代币的数量，根据用户实际选择的份额进行提现
// 注意事项：调用 withdraw 之前，必须调用 Fundtoken 流动性份额代币合约的 approve 函数，并通过对 FundManager 合约地址允许对应的数量，否则没法销毁 Fundtoken 代币
function withdraw(uint256 _amount) external returns (uint256[] memory);
```

### FundController（调度员调用）

```js
// approve 同意调用指定合约的存储和提现
function approveTo(address _token, address _receiver, uint256 _amount) external;

// approve 同意调用 Master 合约进行挖矿
function approveToMaster(address _pair, uint256 _amount) external;

// approve 同意调用 FundManager 合约进行存储和提现
function approveToManager(address _token, uint256 _amount) external;

// 存储流动性代币到 Master 合约池中进行挖矿
function depositToPool(address _pair, uint256 _amount) external;

// 从 Master 合约池中提现流动性代币（可仅提现收益，也可提现本金和收益）
function withdrawFromPool(address _pair, uint256 _amount) external;

// 允许 FundManager 直接将流动性代币存储到 Master 合约池中进行挖矿（间接调用）
function depositToPoolByManager(address _pair, uint256 _amount) external onlyFundManager;

// 允许 FundManager 直接从 Master 合约池中提现流动性代币（间接调用）
function withdrawFromPoolByManager(address _pair, uint256 _amount) external onlyFundManager;

// 流动性代币智能调仓
function rebalance(address _oldPair, address _newPair, uint256 _liquidity, uint256 _deadline) external onlyRebalancer returns (uint256 newLiquidity);

// 查询当前相关 ERC20 代币余额
function getPoolBalance(address _token) public view returns (uint256);

// 查询待领取的挖矿奖励代币金额
function getPoolReward(address _pair) public view returns (uint256);

// 查询已存入挖矿的流动性代币本金数量
function getPoolPrincipal(address _pair) public view returns (uint256 amount);
```

## 测试合约信息

```js
FundController: 0x640ab84C143e841784B220c76b0d7476982E46F4
FundManager: 0x7C5981565331E698bCCB54aDc7Ac531F7C94bD02
FundToken: 0x53d8Ccf38134cE0960Ef709b125368381e824f78
FundMigrator: 0x72919d7E67D043bE569DED8Ba413B5c025C2E034
```

