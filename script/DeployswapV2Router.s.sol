// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {DeployswapV2Factory, MyswapV2Factory} from "./DeployswapV2Factory.s.sol";
import {WETH9} from "../test/mocks/WETH9.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author HangZhou | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract DeployswapV2Router is Script {
    function run() external returns (MyswapV2Factory, WETH9) {
        return deploy();
    }

    function deploy() public returns (MyswapV2Factory myswapV2Factory, WETH9 weth9) {
        DeployswapV2Factory deployswapV2Factory = new DeployswapV2Factory();
        myswapV2Factory = deployswapV2Factory.deploy();

        vm.startBroadcast();
        weth9 = new WETH9();
        vm.stopBroadcast();
    }
}
