// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
}
