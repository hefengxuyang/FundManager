// SPDX-License-Identifier: MIT
// pragma solidity ^0.6.0;
pragma solidity ^0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IController.sol";

contract StrategyXXX {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public governance;
    address public strategist;
    address public controller;
    address public proxy;   // 代理合约地址，LP挖矿的接收地址

    uint256 public earned; // lifetime strategy earnings denominated in `want` token
    uint256 public performanceFee = 5;
    uint256 public constant FEE_DENOMINATOR = 1000;

    address public constant WANT_LP_TOKEN = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public constant REWARD_TOKEN = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public constant BNB_ADDRESS = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address public constant BUSDT_ADDRESS = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    event Harvested(uint256 wantEarned, uint256 lifetimeEarned);

    constructor(address _controller) public {
        governance = msg.sender;
        strategist = msg.sender;
        controller = _controller;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "Caller is not the governance.");
        _;
    }

    modifier onlyStrategistOrGovernance() {
        require(msg.sender == strategist || msg.sender == governance, "Caller is not strategist or governance");
        _;
    }

    function getName() external pure returns (string memory) {
        return "Strategy for harvest XXX";
    }

    function setGovernance(address _governance) external onlyGovernance {
        governance = _governance;
    }

    function setController(address _controller) external onlyGovernance {
        controller = _controller;
    }

    function setStrategist(address _strategist) external onlyStrategistOrGovernance {
        strategist = _strategist;
    }

    function setPerformanceFee(uint256 _performanceFee) external onlyGovernance {
        performanceFee = _performanceFee;
    }

    function deposit() public {
        uint256 _want = IERC20(WANT_LP_TOKEN).balanceOf(address(this));
        if (_want > 0) {
            IERC20(WANT_LP_TOKEN).safeTransfer(proxy, _want);
        }
    }

    // Controller only function for creating additional rewards from dust
    function withdraw() external onlyGovernance returns (uint256 balance) {
        balance = IERC20(WANT_LP_TOKEN).balanceOf(address(this));
        IERC20(WANT_LP_TOKEN).safeTransfer(controller, balance);
    }

    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint256 _amount) external onlyGovernance {
        // TODO 获取LP池所占份额，然后减去对应的份额
        uint256 _balance = IERC20(WANT_LP_TOKEN).balanceOf(address(this));
        require(_balance < _amount, "the balance of governance less than withdraw amout");

        uint256 _fee = _amount.mul(performanceFee).div(FEE_DENOMINATOR);
        IERC20(WANT_LP_TOKEN).safeTransfer(IController(controller).rewards(), _fee);
    }

    function harvest() public {
        // TODO 开始挖矿
        // emit Harvested(_want, earned);
    }

    function balanceOf() public view returns (uint256) {
        return IERC20(WANT_LP_TOKEN).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        return IERC20(WANT_LP_TOKEN).balanceOf(proxy);
    }
}
