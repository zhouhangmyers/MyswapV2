// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DeployswapV2Factory} from "../../script/DeployswapV2Factory.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MyswapV2Pair} from "../../src/MyswapV2Pair.sol";
import {MyswapV2Factory} from "../../src/MyswapV2Factory.sol";
import {IMyswapV2Pair} from "../../src/interfaces/IMyswapV2Pair.sol";
import {Math} from "@openzeppelin-contracts/contracts/utils/math/Math.sol";
import {Vm} from "forge-std/Vm.sol";
import {MyswapV2Callee} from "../../src/MyswapV2Callee.sol";

/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */
contract MyswapV2PairTest is Test {
    using Math for uint256;

    DeployswapV2Factory deployswapV2Factory;
    MyswapV2Factory myswapV2Factory;
    ERC20Mock token1;
    ERC20Mock token2;
    MyswapV2Pair myswapV2Pair;
    IMyswapV2Pair i_pair;

    address pair;
    address user1;
    address user2;
    address factoryOwner = vm.envAddress("DEPLOYER_ADDRESS");
    uint256 privateKey1;
    uint256 privatekey2;

    uint256 constant TOKEN_PRECISION = 10 ** 18;
    uint256 constant INITIAL_BALANCE = 100 * 1e18;

    function setUp() external {
        deployswapV2Factory = new DeployswapV2Factory();
        myswapV2Factory = deployswapV2Factory.run();
        token1 = new ERC20Mock("token1", "t1");
        token2 = new ERC20Mock("token2", "t2");
        (user1, privateKey1) = makeAddrAndKey("user1");
        (user2, privatekey2) = makeAddrAndKey("user2");
        token1.mint(user2, 10 * TOKEN_PRECISION);
        token1.mint(user1, INITIAL_BALANCE);
        token2.mint(user1, INITIAL_BALANCE);
        pair = myswapV2Factory.createPair(address(token1), address(token2));
        i_pair = IMyswapV2Pair(pair);
    }

    // function test_USER1Have100Token1AndToken2() external view {
    //     console2.log("token1 balance", token1.balanceOf(user1));
    //     console2.log("token2 balance", token2.balanceOf(user1));
    // }
    function test_deployIsCorrect() external {
        MyswapV2Factory myswap = deployswapV2Factory.deploy();
        assert(address(myswap).code.length > 0);
    }

    function test_createPairIsCorrect() external view {
        assert(pair.code.length > 0);
        address expectedPair = myswapV2Factory.getPair(address(token1), address(token2));
        assertEq(pair, expectedPair);
        console2.log(pair);
    }

    function test_PairOwnerIsFactory() external view {
        assertEq(address(myswapV2Factory), IMyswapV2Pair(pair).factory());
    }

    function test_tokenIsCorrect() external view {
        (address tokenA, address tokenB) =
            address(token1) < address(token2) ? (address(token1), address(token2)) : (address(token2), address(token1));
        assertEq(tokenA, i_pair.token0());
        assertEq(tokenB, i_pair.token1());
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = i_pair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        assertEq(blockTimestampLast, 0);
    }

    function test_initializeIsError() external {
        vm.expectRevert("MyswapV2: FORBIDDEN");
        i_pair.initialize(address(token1), address(token2));
    }

    function test_mintBalance() external {
        // (uint32 timestamp) = setTokenState();
        // console2.log(token1.balanceOf(pair));
        // console2.log(token2.balanceOf(pair));

        (uint112 reserve0, uint112 reserve1, uint32 timestampLast) = i_pair.getReserves();
        assertEq(0, timestampLast);
        assertEq(0, reserve0);
        assertEq(0, reserve1);

        // console2.log(timestamp);
        // console2.log(timestampLast);
        uint256 beforeUserBalance1 = token1.balanceOf(user1);
        uint256 beforeUserBalance2 = token2.balanceOf(user1);
        uint256 beforePairBalance1 = token1.balanceOf(pair);
        uint256 beforePairBalance2 = token2.balanceOf(pair);
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        uint256 afterUserBalance1 = token1.balanceOf(user1);
        uint256 afterUserBalance2 = token2.balanceOf(user1);
        uint256 afterPairBalance1 = token1.balanceOf(pair);
        uint256 afterPairBalance2 = token2.balanceOf(pair);
        assertEq(beforeUserBalance1 + beforePairBalance1, afterUserBalance1 + afterPairBalance1);
        assertEq(beforeUserBalance2 + beforePairBalance2, afterUserBalance2 + afterPairBalance2);
    }

    function test_mintLiquidity() external {
        (uint112 reserve0, uint112 reserve1,) = i_pair.getReserves();
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        uint256 afterPairBalance1 = token1.balanceOf(pair);
        uint256 afterPairBalance2 = token2.balanceOf(pair);

        (uint256 amount0, uint256 amount1) = (afterPairBalance1 - reserve0, afterPairBalance2 - reserve1);
        uint256 needToSqrt = amount0 * amount1;
        uint256 totalSupply = MyswapV2Pair(pair).totalSupply();
        uint256 liquidity = i_pair.mint(user1);
        uint256 expectedLiquidity;
        {
            if (totalSupply == 0) {
                expectedLiquidity = needToSqrt.sqrt() - i_pair.MINIMUM_LIQUIDITY();
            } else {
                expectedLiquidity = Math.min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);
            }
        }
        assertEq(liquidity, expectedLiquidity);
        console2.log("LPtoken:", liquidity);
    }

    function test_mintRevert() external {
        uint256 amount = i_pair.MINIMUM_LIQUIDITY();
        vm.startPrank(user1);
        token1.transfer(pair, amount);
        token2.transfer(pair, amount);
        vm.stopPrank();
        vm.expectRevert("MyswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        i_pair.mint(user1);

        token1.mint(pair, type(uint112).max);
        token2.mint(pair, type(uint112).max);
        vm.expectRevert("MyswapV2: OVERFLOW");
        i_pair.mint(user1);
    }

    function test_mintCorrect() external {
        token1.mint(pair, 10 * TOKEN_PRECISION);
        token2.mint(pair, 10 * TOKEN_PRECISION);
        (uint112 reserve0, uint112 reserve1,) = i_pair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        // // vm.recordLogs();
        i_pair.mint(user1);
        // // Vm.Log[] memory logs = vm.getRecordedLogs();
        (reserve0, reserve1,) = i_pair.getReserves();
        assertEq(reserve0, 10 * TOKEN_PRECISION);
        assertEq(reserve1, token2.balanceOf(pair));
        // assertEq(reserve1, 10 * TOKEN_PRECISION);
    }

    modifier setTokenState() {
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        _;
    }

    function test_burn() external setTokenState {
        uint256 liquidity = i_pair.mint(user1);
        vm.prank(user1);
        MyswapV2Pair(pair).transfer(pair, liquidity);
        i_pair.burn(user1);
        assertEq(token1.balanceOf(pair), 1000);
        assertEq(token2.balanceOf(pair), 1000);
        console2.log(token1.balanceOf(user1));
        console2.log(token2.balanceOf(user1));
    }

    function test_mintFee() external setTokenState {
        vm.prank(factoryOwner);
        myswapV2Factory.setFeeTo(factoryOwner);

        uint256 liquidity = i_pair.mint(user1);
        (uint112 reserve0, uint112 reserve1, uint32 timestampLast) = i_pair.getReserves();
        vm.warp(timestampLast + 100);
        vm.prank(user1);
        MyswapV2Pair(pair).transfer(pair, liquidity - 5 * TOKEN_PRECISION);
        (uint256 amount0, uint256 amount1) = i_pair.burn(user1);
        console2.log(amount0);
        console2.log(amount1);

        console2.log("TWAP-token0Price", i_pair.price0CumulativeLast() / 2 ** 112 / (block.timestamp - timestampLast));
        console2.log("Bug-token0Price", reserve1 / reserve0);

        uint256 benefits = MyswapV2Pair(pair).balanceOf(factoryOwner);
        console2.log(benefits);
    }

    function test_swap() external setTokenState {
        vm.prank(factoryOwner);
        myswapV2Factory.setFeeTo(factoryOwner);

        // uint256 liquidity = i_pair.mint(user1);
        i_pair.mint(user1);
        vm.expectRevert("MyswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        i_pair.swap(0, 0, user1, new bytes(0));
        vm.expectRevert("MyswapV2: INSUFFICIENT_LIQUIDITY");
        i_pair.swap(INITIAL_BALANCE, INITIAL_BALANCE, user1, new bytes(0));

        (uint112 reserve0, uint112 reserve1,) = i_pair.getReserves();

        // vm.prank(user2);
        uint256 amountIn = 10 * TOKEN_PRECISION;
        // token1.transfer(pair, amountIn);

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserve1;
        uint256 denominator = uint256(reserve0) * 1000 + amountInWithFee;
        uint256 amountOut = numerator / denominator;
        // console2.log(amountOut);
        console2.log("//////////////////////////////before transfer ////////////////////////////");
        console2.log("user2 token0:", token1.balanceOf(user2) / 1e17);
        console2.log("user2 token1:", token2.balanceOf(user2) / 1e17);
        console2.log("pair reserve0", token1.balanceOf(pair) / 1e17);
        console2.log("pair reserve1", token2.balanceOf(pair) / 1e17);

        vm.prank(user2);
        token1.transfer(pair, amountIn);
        i_pair.swap(0, amountOut, user2, new bytes(0));
        console2.log("/////////////////////////////after transfer/////////////////////////////");
        console2.log("user2 token0:", token1.balanceOf(user2) / 1e17);
        console2.log("user2 token1:", token2.balanceOf(user2) / 1e17);
        console2.log("pair reserve0", token1.balanceOf(pair) / 1e17);
        console2.log("pair reserve1", token2.balanceOf(pair) / 1e17);
    }

    function test_skim() external {
        uint256 target = 10 * TOKEN_PRECISION;
        token1.mint(pair, target);
        token2.mint(pair, target);
        uint256 beforeUser2Balance1 = token1.balanceOf(user2);
        uint256 beforeUser2Balance2 = token2.balanceOf(user2);

        i_pair.skim(user2);
        uint256 afterUser2Balance1 = token1.balanceOf(user2);
        uint256 afterUser2Balance2 = token2.balanceOf(user2);

        assertEq(beforeUser2Balance1 + target, afterUser2Balance1);
        assertEq(beforeUser2Balance2 + target, afterUser2Balance2);
    }

    function test_sync() external {
        uint256 target = 10 * TOKEN_PRECISION;
        token1.mint(pair, target);
        token2.mint(pair, target);
        i_pair.sync();
        (uint112 reserve0,,) = i_pair.getReserves();
        assertEq(token1.balanceOf(pair), reserve0);
    }

    function test_ReentrancyAttack() external {
        BugToken bugToken = new BugToken();
        myswapV2Factory.createPair(address(token1), address(bugToken));
        address pair1 = myswapV2Factory.getPair(address(token1), address(bugToken));
        address user = makeAddr("user");
        token1.mint(user, 10 * TOKEN_PRECISION);
        bugToken.mint(user, 10 * TOKEN_PRECISION);
        assertEq(10 * TOKEN_PRECISION, bugToken.balanceOf(user));
        assertEq(10 * TOKEN_PRECISION, bugToken.totalSupply());
        vm.startPrank(user);
        token1.transfer(pair1, 10 * TOKEN_PRECISION);
        bugToken.auto_transfer(pair1, 10 * TOKEN_PRECISION);
        uint256 liquidity = MyswapV2Pair(pair1).mint(user);
        MyswapV2Pair(pair1).transfer(pair1, liquidity);
        vm.expectRevert();
        MyswapV2Pair(pair1).burn(user);
        vm.stopPrank();
    }

    function test_ERC20MockBurn() external {
        token1.burn(user1, INITIAL_BALANCE);
        assertEq(0, token1.balanceOf(user1));
    }

    function test_doDoubleMint() external setTokenState {
        i_pair.mint(address(this));
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        i_pair.mint(address(this));
    }

    function test_INSUFFICIENT_LIQUIDITY_MINTED() external {
        uint256 min = i_pair.MINIMUM_LIQUIDITY();
        vm.startPrank(user1);
        token1.transfer(pair, min);
        token2.transfer(pair, min);
        vm.stopPrank();
        vm.expectRevert("MyswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        i_pair.mint(user1);
    }

    function test_INSUFFICIENT_LIQUIDITY_BURND() external {
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        i_pair.mint(user1);
        // MyswapV2Pair(pair).transfer(pair, 1);
        vm.expectRevert("MyswapV2: INSUFFICIENT_LIQUIDITY_BURND");
        i_pair.burn(user1);
        vm.stopPrank();
    }

    function test_swapToEqualToken0() external {
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        i_pair.mint(address(this));
        vm.expectRevert("MyswapV2: INVALID_TO");
        i_pair.swap(1, 0, address(token1), new bytes(0));
    }

    function test_amount0OutIsOk() external {
        vm.startPrank(user1);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        i_pair.mint(address(this));
        vm.startPrank(user1);
        (address tokenA, address tokenB) =
            address(token1) < address(token2) ? (address(token1), address(token2)) : (address(token2), address(token1));
        ERC20Mock(tokenA).transfer(pair, 10 * TOKEN_PRECISION);
        i_pair.swap(0, 1 * TOKEN_PRECISION, user1, new bytes(0));
        ERC20Mock(tokenB).transfer(pair, 10 * TOKEN_PRECISION);
        i_pair.swap(1 * TOKEN_PRECISION, 0, user1, "");
    }

    function test_flash_swap() external {
        MyswapV2Callee myswapV2callee = new MyswapV2Callee();

        vm.startPrank(user1);
        token1.transfer(address(myswapV2callee), 10 * TOKEN_PRECISION);
        token2.transfer(address(myswapV2callee), 10 * TOKEN_PRECISION);
        token1.transfer(pair, 10 * TOKEN_PRECISION);
        token2.transfer(pair, 10 * TOKEN_PRECISION);
        vm.stopPrank();
        i_pair.mint(user1);
        vm.expectRevert("not exists");
        myswapV2callee.flashLoan(
            address(myswapV2Factory), address(0), address(token2), 1 * TOKEN_PRECISION, 1 * TOKEN_PRECISION
        );
        bytes memory data = abi.encode(pair, TOKEN_PRECISION, TOKEN_PRECISION);
        vm.expectRevert("not equal amount");
        myswapV2callee.myswapV2Call(address(myswapV2callee), TOKEN_PRECISION + 1, TOKEN_PRECISION, data);

        vm.expectRevert("not equal address");
        myswapV2callee.myswapV2Call(address(0), TOKEN_PRECISION, TOKEN_PRECISION, data);
        vm.prank(pair);
        vm.expectRevert("not MyswapV2Callee");
        myswapV2callee.myswapV2Call(address(0), TOKEN_PRECISION, TOKEN_PRECISION, data);

        myswapV2callee.flashLoan(
            address(myswapV2Factory), address(token1), address(token2), 1 * TOKEN_PRECISION, 1 * TOKEN_PRECISION
        );
    }

    function test_INSUFFICIENT_INPUT_AMOUNT() external {
        token1.mint(pair, 10 * TOKEN_PRECISION);
        token2.mint(pair, 10 * TOKEN_PRECISION);
        i_pair.sync();
        vm.expectRevert("MyswapV2: INSUFFICIENT_INPUT_AMOUNT");
        i_pair.swap(10, 0, address(this), "");
    }

    function test_brokeK() external {
        token1.mint(pair, 10 * TOKEN_PRECISION);
        token2.mint(pair, 10 * TOKEN_PRECISION);
        i_pair.sync();

        (, address tokenB) =
            address(token1) < address(token2) ? (address(token1), address(token2)) : (address(token2), address(token1));
        ERC20Mock(tokenB).mint(pair, 2 * TOKEN_PRECISION);
        vm.expectRevert("MyswapV2: K");
        i_pair.swap(5 * TOKEN_PRECISION, 0, address(this), "");
    }

    function test_openMintFee() external {
        vm.prank(factoryOwner);
        myswapV2Factory.setFeeTo(address(this));
        uint256 before = MyswapV2Pair(pair).balanceOf(address(this));
        assertEq(before, 0);
        token1.mint(pair, 10 * TOKEN_PRECISION);
        token2.mint(pair, 10 * TOKEN_PRECISION);

        i_pair.mint(user1);
        (address tokenA, address tokenB) =
            address(token1) < address(token2) ? (address(token1), address(token2)) : (address(token2), address(token1));

        for (uint160 i = 1; i <= 5; i++) {
            address user = address(i);
            ERC20Mock(tokenA).mint(user, 10 * TOKEN_PRECISION);
            vm.prank(user);
            token1.transfer(pair, 10 * TOKEN_PRECISION);
            i_pair.swap(0, 1000, user, "");
        }
        token1.mint(pair, 10 * TOKEN_PRECISION);
        token2.mint(pair, 1 * TOKEN_PRECISION);
        i_pair.mint(user1);
        uint256 protocolFeeReceived = MyswapV2Pair(pair).balanceOf(address(this));
        assert(protocolFeeReceived > 0);
        console2.log("Protocol Fee Received:", protocolFeeReceived);
        console2.log("Protocol Toal LPtoken", MyswapV2Pair(pair).totalSupply());

        vm.prank(address(this));
        MyswapV2Pair(pair).transfer(pair, protocolFeeReceived);

        (uint256 amount0, uint256 amount1) = i_pair.burn(address(this));
        console2.log("token0:", amount0);
        console2.log("token1:", amount1);

        vm.prank(factoryOwner);
        myswapV2Factory.setFeeTo(address(0));

        ERC20Mock(tokenB).mint(pair, 10 * TOKEN_PRECISION);
        i_pair.swap(30 * TOKEN_PRECISION, 0, address(user1), "");
        token1.mint(pair, 10 * TOKEN_PRECISION);
        token2.mint(pair, 1 * TOKEN_PRECISION);
        i_pair.mint(user1);
        protocolFeeReceived = MyswapV2Pair(pair).balanceOf(address(this));
        assertEq(protocolFeeReceived, 0);
    }

    function test_flashSwap() external {}
}

contract BugToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);

    string public name = "BugToken";
    string public symbol = "Bug";
    uint8 public decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    function auto_transfer(address recipient, uint256 amount) external returns (bool) {
        balanceOf[recipient] += amount;
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function fallbacks() private {
        MyswapV2Pair(msg.sender).mint(address(this));
    }

    fallback() external payable {
        fallbacks();
    }

    receive() external payable {}
}
