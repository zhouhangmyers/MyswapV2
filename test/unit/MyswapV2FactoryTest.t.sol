// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MyswapV2Factory} from "../../src/MyswapV2Factory.sol";
import {DeployswapV2Factory} from "../../script/DeployswapV2Factory.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract MyswapV2FactoryTest is Test {
    MyswapV2Factory myswapV2Factory;
    DeployswapV2Factory deploy;
    ERC20Mock token1;
    ERC20Mock token2;
    address account = vm.envAddress("DEPLOYER_ADDRESS");

    function setUp() external {
        deploy = new DeployswapV2Factory();
        myswapV2Factory = deploy.run();
        token1 = new ERC20Mock("token1", "t1");
        token2 = new ERC20Mock("token2", "t2");
    }

    function test_feeToSetterIsCorrect() external view {
        address expected = myswapV2Factory.feeToSetter();
        assertEq(account, expected);
        console2.log(account);
        console2.log(expected);
    }

    function test_setFeeToIsCorrect() external {
        vm.expectRevert("MyswapV2: FORBIDDEN");
        myswapV2Factory.setFeeTo(account);
        assertEq(address(0), myswapV2Factory.feeTo());
        vm.prank(account);
        myswapV2Factory.setFeeTo(account);
        assertEq(account, myswapV2Factory.feeTo());
    }

    function test_setFeeToSetter() external {
        address expected = makeAddr("user1");
        vm.expectRevert("MyswapV2: FORBIDDEN");
        myswapV2Factory.setFeeToSetter(expected);
        assertEq(account, myswapV2Factory.feeToSetter());
        vm.prank(account);
        myswapV2Factory.setFeeToSetter(expected);
        assertEq(expected, myswapV2Factory.feeToSetter());
    }

    function test_createPair() external {
        vm.expectRevert("MyswapV2: IDENTICA_ADDRESSES");
        myswapV2Factory.createPair(address(token1), address(token1));

        vm.expectRevert("MyswapV2: ZERO_ADDRESS");
        myswapV2Factory.createPair(address(0), address(token2));

        vm.recordLogs();
        myswapV2Factory.createPair(address(token1), address(token2));
        vm.expectRevert("MyswapV2: PAIR_EXISTS");
        myswapV2Factory.createPair(address(token1), address(token2));

        address pair1 = myswapV2Factory.getPair(address(token1), address(token2));
        address pair2 = myswapV2Factory.getPair(address(token2), address(token1));
        console2.log("pair1", pair1);
        console2.log("pair2", pair2);
        assertEq(pair1, pair2);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 expectedCount = 1;
        assertEq(logs.length, expectedCount, "length not equal");
        Vm.Log memory log = logs[0];
        bytes32 eventSignature = keccak256(bytes("PairCreated(address,address,address,uint256)"));
        assertEq(eventSignature, log.topics[0]);
        (address tokenA, address tokenB) =
            address(token1) < address(token2) ? (address(token1), address(token2)) : (address(token2), address(token1));
        assertEq(bytes32(uint256(uint160(tokenA))), log.topics[1]);
        assertEq(bytes32(uint256(uint160(tokenB))), log.topics[2]);

        (address pair, uint256 length) = abi.decode(log.data, (address, uint256));
        console2.log("log.data: ", pair);
        assertEq(pair1, pair);
        assertEq(length, myswapV2Factory.allPairsLength());
    }
}
