// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../src/MyswapV2ERC20.sol";
import {Script} from "forge-std/Script.sol";

/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author HangZhou | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */
contract DeployswapV2ERC20 is Script {
    function run() external returns (MyswapV2ERC20) {
        return deploy();
    }

    function deploy() public returns (MyswapV2ERC20) {
        vm.startBroadcast();
        MyswapV2ERC20 myswapV2ERC20 = new MyswapV2ERC20();
        vm.stopBroadcast();

        return myswapV2ERC20;
    }
}
