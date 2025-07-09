// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DeployswapV2Router} from "../../script/DeployswapV2Router.s.sol";
import {WETH9} from "../mocks/WETH9.sol";
import {MyswapV2Factory} from "../../src/MyswapV2Factory.sol";
import {MyswapV2Router} from "../../src/MyswapV2Router.sol";
import {IMyswapV2Pair} from "../../src/interfaces/IMyswapV2Pair.sol";
import {MyswapV2Library} from "../../src/libraries/MyswapV2Library.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {Math} from "@openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IMyswapV2ERC20} from "../../src/interfaces/IMyswapV2ERC20.sol";

/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
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
        vm.deal(user1, 2 * INITIAL_AMOUNT * TOKEN_PRECISION);
        vm.prank(user1);
        weth.deposit{value: INITIAL_AMOUNT * TOKEN_PRECISION}();
        token1.mint(user1, INITIAL_AMOUNT * TOKEN_PRECISION);
        token2.mint(user1, INITIAL_AMOUNT * TOKEN_PRECISION);

        //user2 初始化3类代币
        vm.deal(user2, 2 * INITIAL_AMOUNT * TOKEN_PRECISION);
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

    function test_myswapV2RouterFacotryIscorrect() external view {
        assertEq(address(factory), router.factory());
    }

    function test_myswapV2RouterWETHIscorrect() external view {
        assertEq(payable(address(weth)), router.WETH());
    }

    /*//////////////////////////////////////////////////////////////
                        ADD LIQUIDITY TEST SUIT
    //////////////////////////////////////////////////////////////*/

    function test_addLiquidity() public {
        //第一次添加流动性
        // (uint256 expectedReserve0, uint256 expectedReserve1,) =
        //     IMyswapV2Pair(MyswapV2Library.pairFor(address(factory), address(token1), address(token2))).getReserves();
        (address pair) = factory.createPair(address(token1), address(token2));
        assertEq(pair, MyswapV2Library.pairFor(address(factory), address(token1), address(token2)));
        (uint256 expectedReserveA, uint256 expectedReserveB) =
            MyswapV2Library.getReserves(address(factory), address(token1), address(token2));
        assertEq(expectedReserveA, 0);
        assertEq(expectedReserveB, 0);

        vm.startPrank(user1);
        token1.approve(address(router), type(uint256).max);
        token2.approve(address(router), type(uint256).max);
        (uint256 reserveA, uint256 reserveB, uint256 liquidity) = router.addLiquidity(
            address(token1),
            address(token2),
            10 * TOKEN_PRECISION,
            10 * TOKEN_PRECISION,
            10 * TOKEN_PRECISION,
            10,
            user1,
            block.timestamp + 100
        );
        vm.stopPrank();
        assertEq(reserveA, 10 * TOKEN_PRECISION);
        assertEq(reserveB, 10 * TOKEN_PRECISION);
        assertEq(liquidity, Math.sqrt(reserveA * reserveB) - 1000);
        assertEq(liquidity, IMyswapV2ERC20(factory.getPair(address(token1), address(token2))).balanceOf(user1));

        //测试事件逻辑
        vm.expectRevert("MyswapV2Router: EXPIRED");
        router.addLiquidity(
            address(token1),
            address(token2),
            10 * TOKEN_PRECISION,
            10 * TOKEN_PRECISION,
            0,
            0,
            user1,
            block.timestamp - 1
        );
    }

    function test_addLiquidityETH() public {
        //第一次添加流动性
        vm.startPrank(user1);
        token1.approve(address(router), type(uint256).max);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router.addLiquidityETH{value: 2 * TOKEN_PRECISION}(
            address(token1), 2 * TOKEN_PRECISION, 2 * TOKEN_PRECISION, 2 * TOKEN_PRECISION, user1, block.timestamp + 10
        );
        (address pair) = factory.getPair(address(token1), payable(address(weth)));
        assertEq(amountToken, 2 * TOKEN_PRECISION);
        assertEq(amountETH, 2 * TOKEN_PRECISION);
        assertEq(liquidity, Math.sqrt(amountToken * amountETH) - 1000);
        //判断user1得到的Lptoken是否为预期值
        assertEq(IMyswapV2ERC20(pair).balanceOf(user1), liquidity);
        vm.stopPrank();

        //第二次添加流动性
        vm.startPrank(user2);
        uint256 beforeETHAmount = address(user2).balance;
        token1.approve(address(router), type(uint256).max);
        (amountToken, amountETH, liquidity) = router.addLiquidityETH{value: 3 * TOKEN_PRECISION}(
            address(token1), 2 * TOKEN_PRECISION, 2 * TOKEN_PRECISION, 2 * TOKEN_PRECISION, user2, block.timestamp + 10
        );
        vm.stopPrank();
        uint256 afterETHAmount = address(user2).balance;
        assertEq(beforeETHAmount - 2 * TOKEN_PRECISION, afterETHAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        REMOVE LIQUIDITY TEST SUIT
    //////////////////////////////////////////////////////////////*/

    function test_removeLiquidity() external {
        //添加流动性
        test_addLiquidity();
        //移除流动性
        vm.startPrank(user1);
        (address pair) = factory.getPair(address(token1), address(token2));
        (uint256 liquidity) = IMyswapV2ERC20(pair).balanceOf(user1);
        IMyswapV2ERC20(pair).approve(address(router), type(uint256).max);
        (uint256 amountA, uint256 amountB) =
            router.removeLiquidity(address(token1), address(token2), liquidity, 0, 0, user1, block.timestamp + 100);
        assertEq(amountA, 10 * TOKEN_PRECISION - 1000);
        assertEq(amountB, 10 * TOKEN_PRECISION - 1000);
        (uint256 reserve0, uint256 reserve1,) = IMyswapV2Pair(pair).getReserves();
        assertEq(reserve0, 1000);
        assertEq(reserve1, 1000);
        vm.stopPrank();
    }

    function test_removeLiquidityETH() external {
        //添加流动性
        test_addLiquidityETH();
        //移除流动性
        vm.startPrank(user1);
        (address pair) = factory.getPair(address(token1), payable(address(weth)));
        uint256 liquidity = IMyswapV2ERC20(pair).balanceOf(user1);
        IMyswapV2ERC20(pair).approve(address(router), type(uint256).max);
        (uint256 reserve0, uint256 reserve1,) = IMyswapV2Pair(pair).getReserves();
        (address token0,) = MyswapV2Library.sortTokens(address(token1), payable(address(weth)));
        (uint256 token1Reserve, uint256 ethReserve) =
            token0 == address(token1) ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 expectedToken = liquidity * token1Reserve / IMyswapV2ERC20(pair).totalSupply();
        uint256 expectedEth = liquidity * ethReserve / IMyswapV2ERC20(pair).totalSupply();
        (uint256 amountToken, uint256 amountEth) =
            router.removeLiquidityETH(address(token1), liquidity, 0, 0, user1, block.timestamp + 100);
        vm.stopPrank();
        assertEq(amountToken, expectedToken);
        assertEq(amountEth, expectedEth);
    }

    function test_getUser1MaxPermit() public view returns (uint8 v, bytes32 r, bytes32 s, uint256 deadline) {
        deadline = block.timestamp + 100;
        address pair = factory.getPair(address(token1), address(token2));
        bytes32 DOMAIN_TYPEHASH =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        DOMAIN_TYPEHASH,
                        keccak256(bytes("Myswap V2")),
                        keccak256(bytes("1")),
                        block.chainid,
                        address(pair)
                    )
                ),
                keccak256(abi.encode(PERMIT_TYPEHASH, user1, address(router), type(uint256).max, 0, deadline))
            )
        );

        (v, r, s) = vm.sign(privatekey1, digest);
    }

    function test_getUser1MaxEthPermit() public view returns (uint8 v, bytes32 r, bytes32 s, uint256 deadline) {
        deadline = block.timestamp + 100;
        address pair = factory.getPair(address(token1), payable(address(weth)));
        bytes32 DOMAIN_TYPEHASH =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        DOMAIN_TYPEHASH,
                        keccak256(bytes("Myswap V2")),
                        keccak256(bytes("1")),
                        block.chainid,
                        address(pair)
                    )
                ),
                keccak256(abi.encode(PERMIT_TYPEHASH, user1, address(router), type(uint256).max, 0, deadline))
            )
        );

        (v, r, s) = vm.sign(privatekey1, digest);
    }

    /*//////////////////////////////////////////////////////////////
               REMOVE WITH PREMIT LIQUIDITY TEST SUIT
    //////////////////////////////////////////////////////////////*/

    function test_removeLiquidityWithPermit() external {
        //user1添加流动性
        vm.startPrank(user1);
        token1.approve(address(router), type(uint256).max);
        token2.approve(address(router), type(uint256).max);
        (,, uint256 liquidity) = router.addLiquidity(
            address(token1),
            address(token2),
            10 * TOKEN_PRECISION,
            10 * TOKEN_PRECISION,
            10 * TOKEN_PRECISION,
            10,
            user1,
            block.timestamp + 100
        );
        vm.stopPrank();
        //使用user1Max进行签名
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
        {
            (v, r, s, deadline) = test_getUser1MaxPermit();

            //** removeLiquidityWithPermit规则是谁签名，谁调用，即便他人知道VRS，也无法调用 */
            vm.startPrank(user1);
            (uint256 amountA, uint256 amountB) = router.removeLiquidityWithPermit(
                address(token1), address(token2), liquidity, 0, 0, user2, deadline, true, v, r, s
            );
            console2.log(amountA);
            console2.log(amountB);
            assertEq(token1.balanceOf(user2), INITIAL_AMOUNT * TOKEN_PRECISION + amountA);
        }
    }

    function test_removeLiquidityETHWithPermit() external {
        //第一次是user1铸造各2枚，第二次是user2铸造各2枚
        test_addLiquidityETH();
        uint256 liquidity = IMyswapV2ERC20(factory.getPair(address(token1), payable(address(weth)))).balanceOf(user1);
        //使用user1Max进行签名
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;

        {
            (v, r, s, deadline) = test_getUser1MaxEthPermit();

            //** removeLiquidityWithPermit规则是谁签名，谁调用，即便他人知道VRS，也无法调用 */
            vm.startPrank(user1);
            (uint256 amountToken, uint256 amountEth) =
                router.removeLiquidityETHWithPermit(address(token1), liquidity, 0, 0, user1, deadline, true, v, r, s);
            vm.stopPrank();
            console2.log(amountToken);
            console2.log(amountEth);
            assertEq(token1.balanceOf(user1), INITIAL_AMOUNT * TOKEN_PRECISION - 1000);
            assertEq(user1.balance, INITIAL_AMOUNT * TOKEN_PRECISION - 1000);
        }
    }

    function test_removeLiquidityETHSupportingFeeOnTransferTokens() external {
        //第一次是user1铸造各2枚，第二次是user2铸造各2枚
        test_addLiquidityETH();
        uint256 liquidity = IMyswapV2ERC20(factory.getPair(address(token1), payable(address(weth)))).balanceOf(user1);
        //使用user1Max进行签名

        //** removeLiquidityWithPermit规则是谁签名，谁调用，即便他人知道VRS，也无法调用 */
        vm.startPrank(user1);
        //** 给router合约最大化授权 */
        IMyswapV2ERC20(factory.getPair(address(token1), payable(address(weth)))).approve(
            address(router), type(uint256).max
        );
        uint256 amountEth = router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(token1), liquidity, 0, 0, user1, block.timestamp + 100
        );
        vm.stopPrank();
        console2.log(amountEth);
        assertEq(token1.balanceOf(user1), INITIAL_AMOUNT * TOKEN_PRECISION - 1000);
        assertEq(user1.balance, INITIAL_AMOUNT * TOKEN_PRECISION - 1000);
    }

    function test_removeLiquidityETHWithPermitSupportingFeeOnTransferTokens() external {
        //第一次是user1铸造各2枚，第二次是user2铸造各2枚
        test_addLiquidityETH();
        uint256 liquidity = IMyswapV2ERC20(factory.getPair(address(token1), payable(address(weth)))).balanceOf(user1);
        //使用user1Max进行签名
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;

        {
            (v, r, s, deadline) = test_getUser1MaxEthPermit();

            //** removeLiquidityWithPermit规则是谁签名，谁调用，即便他人知道VRS，也无法调用 */
            vm.startPrank(user1);
            uint256 amountEth = router.removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
                address(token1), liquidity, 0, 0, user1, deadline, true, v, r, s
            );
            vm.stopPrank();
            console2.log(amountEth);
            assertEq(token1.balanceOf(user1), INITIAL_AMOUNT * TOKEN_PRECISION - 1000);
            assertEq(user1.balance, INITIAL_AMOUNT * TOKEN_PRECISION - 1000);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SWAP TEST FUNCTION SUIT
    //////////////////////////////////////////////////////////////*/
    function test_swapExactTokensForTokens() external {
        test_addLiquidity();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        uint256 beforeAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        ERC20Mock(path[0]).approve(address(router), type(uint256).max);
        router.swapExactTokensForTokens(10 * TOKEN_PRECISION, 0, path, user1, block.timestamp + 10);
        uint256 afterAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        vm.stopPrank();
        assert(afterAmount > beforeAmount);
    }

    /**
     * MyswapV2Library的getAmountsIn中 path.length >= 2
     */
    function test_swapTokensForExactTokens() external {
        test_addLiquidity();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        uint256 beforeAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        ERC20Mock(path[path.length - 1]).approve(address(router), type(uint256).max);
        router.swapTokensForExactTokens(5 * TOKEN_PRECISION, 20 * TOKEN_PRECISION, path, user1, block.timestamp + 100);
        uint256 afterAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        vm.stopPrank();
        assert(afterAmount > beforeAmount);
    }

    function test_swapExactETHForTokens() external {
        test_addLiquidityETH();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = payable(address(weth));
        path[1] = address(token1);
        uint256 beforeAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        router.swapExactETHForTokens{value: 1 * TOKEN_PRECISION}(0, path, user1, block.timestamp + 10);
        uint256 afterAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        vm.stopPrank();
        assert(afterAmount > beforeAmount);
    }

    function test_swapTokensForExactETH() external {
        test_addLiquidityETH();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = payable(address(weth));
        ERC20Mock(path[0]).approve(address(router), type(uint256).max);
        uint256 beforeEth = user1.balance;
        router.swapTokensForExactETH(1 * TOKEN_PRECISION, 3 * TOKEN_PRECISION, path, user1, block.timestamp + 10);
        uint256 afterEth = user1.balance;
        vm.stopPrank();
        assert(afterEth > beforeEth);
    }

    function test_swapExactTokensForETH() external {
        test_addLiquidityETH();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = payable(address(weth));
        ERC20Mock(path[0]).approve(address(router), type(uint256).max);
        uint256 beforeEth = user1.balance;
        router.swapExactTokensForETH(1 * TOKEN_PRECISION, 0, path, user1, block.timestamp + 10);
        uint256 afterEth = user1.balance;
        vm.stopPrank();
        assert(afterEth > beforeEth);
        console2.log(afterEth - beforeEth);
    }

    function test_swapETHForExactTokens() external {
        test_addLiquidityETH();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = payable(address(weth));
        path[1] = address(token1);
        uint256 beforeAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        router.swapETHForExactTokens{value: 2 * TOKEN_PRECISION}(1 * TOKEN_PRECISION, path, user1, block.timestamp + 10);
        uint256 afterAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        vm.stopPrank();
        assert(afterAmount > beforeAmount);
        console2.log(afterAmount - beforeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                 SWAP SUPPORTING FEE-ON-TRANSFER TOKENS
    //////////////////////////////////////////////////////////////*/
    function test_swapExactTokensForTokensSupportingFeeOnTransferTokens() external {
        test_addLiquidity();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        ERC20Mock(path[0]).approve(address(router), type(uint256).max);
        uint256 beforeAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            10 * TOKEN_PRECISION, 0, path, user1, block.timestamp + 10
        );
        uint256 afterAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        vm.stopPrank();
        assert(afterAmount > beforeAmount);
        console2.log(afterAmount - beforeAmount);
    }

    function test_swapExactETHForTokensSupportingFeeOnTransferTokens() external {
        test_addLiquidityETH();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = payable(address(weth));
        path[1] = address(token1);
        uint256 beforeAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1 * TOKEN_PRECISION}(
            0, path, user1, block.timestamp
        );
        uint256 afterAmount = ERC20Mock(path[path.length - 1]).balanceOf(user1);
        vm.stopPrank();
        assert(afterAmount > beforeAmount);
        console2.log(afterAmount - beforeAmount);
    }

    function test_swapExactTokensForETHSupportingFeeOnTransferTokens() external {
        test_addLiquidityETH();
        vm.startPrank(user1);
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = payable(address(weth));
        ERC20Mock(path[0]).approve(address(router), type(uint256).max);
        uint256 beforeEth = user1.balance;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            1 * TOKEN_PRECISION, 0, path, user1, block.timestamp + 10
        );
        uint256 afterEth = user1.balance;
        vm.stopPrank();
        assert(afterEth > beforeEth);
        console2.log(afterEth - beforeEth);
    }

    /*//////////////////////////////////////////////////////////////
                     LIBRARY FUNCTIONS SUIT
    //////////////////////////////////////////////////////////////*/
    function test_quote() external view {
        uint256 amountA = 10 * TOKEN_PRECISION;
        uint256 reserveA = 100 * TOKEN_PRECISION;
        uint256 reserveB = 100 * TOKEN_PRECISION;
        uint256 amountB = amountA * reserveB / reserveA;
        assertEq(amountB, router.quote(amountA, reserveA, reserveB));
    }

    function test_getAmountOut() external view {
        uint256 amountIn = 10 * TOKEN_PRECISION;
        uint256 reserveIn = 10 * TOKEN_PRECISION;
        uint256 reserveOut = 100 * TOKEN_PRECISION;

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = reserveOut * amountInWithFee;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        assertEq(amountOut, router.getAmountOut(amountIn, reserveIn, reserveOut));
    }

    function test_getAmountIn() external view {
        uint256 amountOut = 10 * TOKEN_PRECISION;
        uint256 reserveIn = 10 * TOKEN_PRECISION;
        uint256 reserveOut = 100 * TOKEN_PRECISION;

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        uint256 amountIn = numerator / denominator + 1;

        assertEq(amountIn, router.getAmountIn(amountOut, reserveIn, reserveOut));
    }

    function test_getAmountsOut() external {
        test_addLiquidity();
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        (uint256[] memory amounts) = router.getAmountsOut(5 * TOKEN_PRECISION, path);
        //输出在3.几个 将近3个
        console2.log(amounts[path.length - 1]);
    }

    function test_getAmountsIn() external {
        test_addLiquidity();
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);

        (uint256[] memory amounts) = router.getAmountsIn(5 * TOKEN_PRECISION, path);
        //10 * 10 = 100
        // x * 5 = 100
        //x = 20
        //要多输入手续费 20-10 +fee = 稍稍大于10.03个左右 将近10个
        console2.log(amounts[0]);
    }

    /*//////////////////////////////////////////////////////////////
                            WETH9 TEST SUIT
    //////////////////////////////////////////////////////////////*/
    function test_variables() external view {
        console2.log(weth.name());
        console2.log(weth.symbol());
        console2.log(weth.decimals());
    }

    function test_receive() external {
        vm.prank(user1);
        (bool success,) = payable(address(weth)).call{value: 1 * TOKEN_PRECISION}("");
        require(success);
        console2.log(weth.balanceOf(user1));
    }

    function test_deposit() public {
        vm.prank(user1);
        weth.deposit{value: 1 * TOKEN_PRECISION}();
        console2.log(weth.balanceOf(user1));
    }

    function test_withdraw() external {
        test_deposit();
        vm.prank(user1);
        weth.withdraw(1 * TOKEN_PRECISION);
        console2.log(weth.balanceOf(user1));
    }

    function test_approve() public {
        test_deposit();
        vm.prank(user1);
        weth.approve(user2, 1 * TOKEN_PRECISION);
    }

    function test_allowance() public {
        test_approve();
        console2.log(weth.allowance(user1, user2));
    }

    function test_transfer() external {
        test_deposit();
        vm.prank(user1);
        weth.transfer(user2, 1 * TOKEN_PRECISION);
        //101*1e18
        console2.log(weth.balanceOf(user2));
    }

    function test_transferFrom() external {
        test_deposit();
        vm.prank(user1);
        weth.transferFrom(user1, user2, 1 * TOKEN_PRECISION);
    }

    /*//////////////////////////////////////////////////////////////
                         WETH9 BRANCH TEST SUIT 
    //////////////////////////////////////////////////////////////*/

    function test_revert_withdraw() external {
        vm.expectRevert("insufficient balance");
        weth.withdraw(10 * TOKEN_PRECISION);
    }

    function test_revert_trasnferFrom() external {
        vm.expectRevert("insufficient balance");
        weth.transferFrom(address(this), user2, 10 * TOKEN_PRECISION);

        test_deposit();
        vm.expectRevert("insufficient allowance");
        weth.transferFrom(user1, user2, 1 * TOKEN_PRECISION);

        vm.prank(user1);
        weth.approve(user2, 10 * TOKEN_PRECISION);
        vm.prank(user2);
        weth.transferFrom(user1, user2, 1 * TOKEN_PRECISION);
    }

    /*//////////////////////////////////////////////////////////////
                  MyswapV2Library BRANCH TEST SUIT 
    //////////////////////////////////////////////////////////////*/
    function test_revert_sortTokens_identical() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: IDENTICAL_ADDRRESS");
        helper.callSortTokensIdentical(address(token1));
    }

    function test_revert_sortTokens_zero() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: ZERO_ADDRESS");
        helper.callSortTokensZero(address(token1));
    }

    function test_revert_quote_zero_amount() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: INSUFFICIENT_AMOUNT");
        helper.callQuote(0, 1000, 1000);
    }

    function test_revert_quote_zero_liquidity() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: INSUFFICIENT_LIQUIDITY");
        helper.callQuote(1, 0, 0);
    }

    function test_revert_getAmountOut_zero_input() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        helper.callGetAmountOut(0, 1000, 1000);
    }

    function test_revert_getAmountOut_zero_liquidity() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: INSUFFICIENT_LIQUIDITY");
        helper.callGetAmountOut(1, 0, 0);
    }

    function test_revert_getAmountIn_zero_output() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("MyswapV2Library: INSUFFICENT_OUTPUT_AMOUNT");
        helper.callGetAmountIn(0, 1000, 1000);
    }

    function test_revert_getAmountIn_zero_liquidity() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        vm.expectRevert("UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        helper.callGetAmountIn(1, 0, 0);
    }

    function test_revert_getAmountsOut_invalidPath() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        address[] memory path = new address[](1);
        vm.expectRevert("MyswapV2Library: INVALID_PATH");
        helper.callGetAmountsOut(address(this), 1000, path);
    }

    function test_revert_getAmountsIn_invalidPath() external {
        MyswapV2LibraryHelper helper = new MyswapV2LibraryHelper();
        address[] memory path = new address[](1);
        vm.expectRevert("MyswapV2Library: INVALID_PATH");
        helper.callGetAmountsIn(address(this), 1000, path);
    }
}

contract MyswapV2LibraryHelper {
    function callSortTokensIdentical(address token) external pure {
        MyswapV2Library.sortTokens(token, token);
    }

    function callSortTokensZero(address token) external pure {
        MyswapV2Library.sortTokens(address(0), token);
    }

    function callQuote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256) {
        return MyswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function callGetAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256)
    {
        return MyswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function callGetAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256)
    {
        return MyswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function callGetAmountsOut(address factory, uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory)
    {
        return MyswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function callGetAmountsIn(address factory, uint256 amountOut, address[] memory path)
        external
        view
        returns (uint256[] memory)
    {
        return MyswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}
