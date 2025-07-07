// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DeployswapV2Router} from "../../script/DeployswapV2Router.s.sol";
import {WETH9} from "../mocks/WETH9.sol";
import {MyswapV2Factory} from "../../src/MyswapV2Factory.sol";
import {MyswapV2Router} from "../../src/MyswapV2Router.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author HangZhou | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract MyswapV2RouterTest is Test {
    WETH9 weth;
    MyswapV2Factory factory;
    address factoryOwner = vm.envAddress("DEPLOYER_ADDRESS");
    DeployswapV2Router deployRouter;
    MyswapV2Router router;
    address user1;
    address user2;
    uint256 privatekey1;
    uint256 privatekey2;
    ERC20Mock token1;
    ERC20Mock token2;
    uint256 constant TOKEN_PRECISION = 1e18;
    uint256 constant INITIAL_AMOUNT = 100;

    function setUp() external {
        deployRouter = new DeployswapV2Router();
        (factory, weth) = deployRouter.run();
        router = new MyswapV2Router(address(factory), payable(address(weth)));
        token1 = new ERC20Mock("token1", "tk1");
        token2 = new ERC20Mock("token2", "tk2");
        (user1, privatekey1) = makeAddrAndKey("user1");
        (user2, privatekey2) = makeAddrAndKey("user2");

        //user1 初始化3类代币
        vm.deal(user1, INITIAL_AMOUNT * TOKEN_PRECISION);
        vm.prank(user1);
        weth.deposit{value: INITIAL_AMOUNT * TOKEN_PRECISION}();
        token1.mint(user1, INITIAL_AMOUNT * TOKEN_PRECISION);
        token2.mint(user1, INITIAL_AMOUNT * TOKEN_PRECISION);

        //user2 初始化3类代币
        vm.deal(user2, INITIAL_AMOUNT * TOKEN_PRECISION);
        vm.prank(user2);
        weth.deposit{value: INITIAL_AMOUNT * TOKEN_PRECISION}();
        token1.mint(user2, INITIAL_AMOUNT * TOKEN_PRECISION);
        token2.mint(user2, INITIAL_AMOUNT * TOKEN_PRECISION);
    }

    function test_DelpoyV2RouterIsCorrect() external {
        (MyswapV2Factory factory2, WETH9 weth2) = deployRouter.deploy();
        assert(address(factory) != address(factory2));
        assert(payable(weth) != payable(weth2));
    }

    function test_User1BalanceIsCorrect() external view {
        uint256 token1Amount = token1.balanceOf(user1);
        uint256 token2Amount = token2.balanceOf(user1);
        uint256 wethAmount = weth.balanceOf(user1);
        assertEq(INITIAL_AMOUNT * TOKEN_PRECISION, token1Amount);
        assertEq(INITIAL_AMOUNT * TOKEN_PRECISION, token2Amount);
        assertEq(INITIAL_AMOUNT * TOKEN_PRECISION, wethAmount);
        console2.log("token1", token1Amount);
        console2.log("token2", token2Amount);
        console2.log("WETH", wethAmount);
    }

    function test_User2BalanceIsCorrect() external view {
        uint256 token1Amount = token1.balanceOf(user2);
        uint256 token2Amount = token2.balanceOf(user2);
        uint256 wethAmount = weth.balanceOf(user2);
        assertEq(INITIAL_AMOUNT * TOKEN_PRECISION, token1Amount);
        assertEq(INITIAL_AMOUNT * TOKEN_PRECISION, token2Amount);
        assertEq(INITIAL_AMOUNT * TOKEN_PRECISION, wethAmount);
        console2.log("token1", token1Amount);
        console2.log("token2", token2Amount);
        console2.log("WETH", wethAmount);
    }
}
