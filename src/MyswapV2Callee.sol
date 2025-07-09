// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IMyswapV2Callee} from "./interfaces/IMyswapV2Callee.sol";
import {IMyswapV2Pair} from "./interfaces/IMyswapV2Pair.sol";
import {IMyswapV2Factory} from "./interfaces/IMyswapV2Factory.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract MyswapV2Callee is IMyswapV2Callee {
    bool locked;

    modifier lock() {
        require(!locked, "Locked");
        locked = !locked;
        _;
        locked = !locked;
    }
    //自定义函数

    function flashLoan(address factory, address token0, address token1, uint256 brrowAmount0, uint256 brrowAmount1)
        external
        lock
    {
        address pair = IMyswapV2Factory(factory).getPair(token0, token1);
        require(pair != address(0), "not exists");
        bytes memory data = abi.encode(pair, brrowAmount0, brrowAmount1);
        IMyswapV2Pair(pair).swap(brrowAmount0, brrowAmount1, address(this), data);
    }

    //实现函数
    function myswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        (address pair, uint256 brrowAmount0, uint256 brrowAmount1) = abi.decode(data, (address, uint256, uint256));
        require(brrowAmount0 == amount0 && brrowAmount1 == amount1, "not equal amount");
        require(pair == msg.sender, "not equal address");
        require(sender == address(this), "not MyswapV2Callee");
        address token0 = IMyswapV2Pair(pair).token0();
        address token1 = IMyswapV2Pair(pair).token1();

        // 操作逻辑(比如套利)
        // .................
        //.....................

        if (amount0 > 0) {
            uint256 fee0 = (amount0 * 3) / 997 + 1;
            uint256 repayment0 = amount0 + fee0;
            IERC20(token0).transfer(msg.sender, repayment0);
        }

        if (amount1 > 0) {
            uint256 fee1 = (amount1 * 3) / 997 + 1;
            uint256 repayment1 = amount1 + fee1;
            IERC20(token1).transfer(msg.sender, repayment1);
        }
    }
}
