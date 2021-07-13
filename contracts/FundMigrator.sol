// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/swap/ISwapV2Factory.sol';
import './interfaces/swap/ISwapV2Pair.sol';
import './interfaces/swap/ISwapV2Router.sol';

/**
 * @title FundMigrator
 * @notice FundMigrator remove old liquity and add new liquity.
 */
contract FundMigrator {
    using SafeMath for uint256;

    address public governance;
    uint256 private desiredRate;

    event DesiredRateSet(uint256 _rate);
    event Split(uint256 _amountA, uint256 _amountB, uint256 _liquidity);
    event Compose(uint256 _amountA, uint256 _amountB, uint256 _liquidity);

    constructor() public {
        governance = msg.sender;
    }

    modifier onlyGovernance() {
        require(governance == msg.sender, "Caller is not the governance.");
        _;
    }

    // 设置容忍的流动性迁移误差比例（即分子占比，分母固定为1000）
    function setDesiredRate(uint256 _rate) external onlyGovernance {
        require(_rate != desiredRate, "This is already the current swap desired rate.");
        require(_rate <= 1e18, "The swap desired rate cannot be greater than 100%.");
        desiredRate = _rate;
        emit DesiredRateSet(_rate);
    }

    // 获取容忍的流动性迁移误差比例
    function getDesiredRate() public view returns(uint256) {
        return desiredRate;
    }

    // token代币地址排序
    function sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        require(_tokenA != _tokenB, 'IDENTICAL_ADDRESS');
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
    }

    // 提取LP代币
    function split(
        address _router, 
        address _tokenA, 
        address _tokenB, 
        uint256 _liquidity) internal returns (uint256 amountA, uint256 amountB) {
        address factory = ISwapV2Router(_router).factory();
        address pair = ISwapV2Factory(factory).getPair(_tokenA, _tokenB);
        require(ISwapV2Pair(pair).transferFrom(msg.sender, pair, _liquidity), 'TRANSFER_FROM_FAILED');
        (amountA, amountB) = ISwapV2Pair(pair).burn(address(this));
        emit Split(amountA, amountB, _liquidity);
    }
    
    // 重组LP代币
    function compose(
        address _router,
        address _tokenA, 
        address _tokenB, 
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _deadline) internal returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        uint256 minAmountADesired = _amountADesired.mul(desiredRate).div(1e18);
        uint256 minAmountBDesired = _amountBDesired.mul(desiredRate).div(1e18);
        TransferHelper.safeApprove(_tokenA, _router, _amountADesired);
        TransferHelper.safeApprove(_tokenB, _router, _amountBDesired);
        (amountA, amountB, liquidity) = ISwapV2Router(_router).addLiquidity(
            _tokenA,
            _tokenB,
            _amountADesired,
            _amountBDesired,
            minAmountADesired,
            minAmountBDesired,
            msg.sender,
            _deadline
        ); 
        emit Compose(amountA, amountB, liquidity);
    }

    // 迁移功能
    function migrate(
        address _oldRouter, 
        address _newRouter, 
        address _tokenA, 
        address _tokenB, 
        uint256 _oldLiquidity,
        uint256 _deadline) external returns (uint256) {
        require(_oldRouter != address(0) && _newRouter != address(0), "ZERO_ADDRESS_FOR_ROUTER");
        (address tokenA, address tokenB) = sortTokens(_tokenA, _tokenB);
        (uint256 amountA, uint256 amountB) = split(
            _oldRouter,
            tokenA,
            tokenB,
            _oldLiquidity
        );
        (uint256 newAmountA, uint256 newAmountB, uint256 newLiquidity) = compose(
            _newRouter,
            tokenA,
            tokenB,
            amountA,
            amountB,
            _deadline
        );
        if (amountA > newAmountA) {
            TransferHelper.safeApprove(tokenA, _newRouter, 0); // be a good blockchain citizen, reset allowance to 0
            TransferHelper.safeTransfer(tokenA, msg.sender, amountA - newAmountA);
        } else if (amountB > newAmountB) {
            TransferHelper.safeApprove(tokenB, _newRouter, 0);
            TransferHelper.safeTransfer(tokenB, msg.sender, amountB - newAmountB);
        }
        return newLiquidity;
    }
}
