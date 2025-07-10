// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DeployswapV2ERC20} from "../../script/DeployswapV2ERC20.s.sol";
import {MyswapV2ERC20} from "../../src/MyswapV2ERC20.sol";

/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */
contract MyswapV2ERC20Test is Test {
    DeployswapV2ERC20 deploy_SwapV2ERC20;
    MyswapV2ERC20 swapV2ERC20;
    address user1;
    address user2;
    uint256 privatekey1;
    uint256 privatekey2;
    uint256 constant TOKEN_PRECISION = 1e18;
    TestToken testToken;

    function setUp() public {
        deploy_SwapV2ERC20 = new DeployswapV2ERC20();
        swapV2ERC20 = deploy_SwapV2ERC20.run();
        (user1, privatekey1) = makeAddrAndKey("user1");
        (user2, privatekey2) = makeAddrAndKey("user2");
        testToken = new TestToken();
    }

    /*//////////////////////////////////////////////////////////////
                           DEPLOYSWAPV2ERC20
    //////////////////////////////////////////////////////////////*/
    function testSwapV2ERC20RunTimeCodeIsMoreThanZero() external view {
        assert(address(swapV2ERC20) != address(0));
        assert(address(swapV2ERC20).code.length > 0);
        assertEq(swapV2ERC20.decimals(), 18);
    }

    function testdeployCanBeUse() external {
        assert(address(deploy_SwapV2ERC20.deploy()) != address(0));
        assert(address(deploy_SwapV2ERC20.deploy()).code.length > 0);
        assertEq(deploy_SwapV2ERC20.deploy().name(), "Myswap V2");
    }

    /*//////////////////////////////////////////////////////////////
                             MYSWAPV2ERC20
    //////////////////////////////////////////////////////////////*/
    function testMetadataContentIsCorrect() external view {
        string memory name = swapV2ERC20.name();
        string memory symbol = swapV2ERC20.symbol();
        uint8 decimals = swapV2ERC20.decimals();
        assertEq(keccak256(bytes(name)), keccak256(bytes("Myswap V2")));
        assertEq(keccak256(bytes(symbol)), keccak256(bytes("MY-V2")));
        assertEq(keccak256(abi.encodePacked(decimals)), keccak256(abi.encodePacked(uint8(18))));
    }

    function testConstructorIsCorrect() external view {
        uint256 chainId = block.chainid;
        bytes32 hash = keccak256(
            abi.encode(
                //////////"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Myswap V2")),
                keccak256(bytes("1")),
                //31337
                chainId,
                address(swapV2ERC20)
            )
        );

        assertEq(chainId, swapV2ERC20.GET_INITIAL_CHAIN_ID(), "failed 1");
        assertEq(hash, swapV2ERC20.GET_INITIAL_DOMAIN_SEPARATOR(), "failed 2");
    }

    function testApprove() external {
        vm.prank(user1);
        uint256 amount = 10;
        swapV2ERC20.approve(user2, amount * TOKEN_PRECISION);
        uint256 actualApproved = swapV2ERC20.allowance(user1, user2);
        assertEq(amount * TOKEN_PRECISION, actualApproved);
    }

    function testMintIsCorrect() external {
        uint256 mintAmount = 100 * TOKEN_PRECISION;
        testToken.mint(user1, mintAmount);
        uint256 balances = testToken.balanceOf(user1);
        assertEq(balances, mintAmount);
    }

    function testBurnIsCorrect() external {
        uint256 mintAmount = 100 * TOKEN_PRECISION;
        testToken.mint(user1, mintAmount);
        uint256 balances1 = testToken.balanceOf(user1);
        assertEq(balances1, mintAmount);
        uint256 burnAmount = 50 * TOKEN_PRECISION;
        testToken.burn(user1, burnAmount);
        uint256 balances2 = testToken.balanceOf(user1);
        assertEq(balances2, balances1 / 2);
    }

    function testTransferIsCorrect() external {
        uint256 mintAmount = 100 * TOKEN_PRECISION;
        testToken.mint(user1, mintAmount);
        uint256 beforeUser1Transfer = testToken.balanceOf(user1);
        uint256 beforeUser2Transfer = testToken.balanceOf(user2);
        uint256 transferAmount = 30 * TOKEN_PRECISION;
        vm.prank(user1);
        testToken.transfer(user2, transferAmount);
        uint256 afterUser1Transfer = testToken.balanceOf(user1);
        uint256 afterUser2Transfer = testToken.balanceOf(user2);
        assertEq(afterUser1Transfer, mintAmount - transferAmount);
        assertEq(afterUser2Transfer, transferAmount);
        assertEq(beforeUser1Transfer + beforeUser2Transfer, afterUser1Transfer + afterUser2Transfer);
    }

    function testTransferFromIsCorrect() external {
        uint256 mintAmount = 100 * TOKEN_PRECISION;
        testToken.mint(user1, mintAmount);
        uint256 beforeUser1Transfer = testToken.balanceOf(user1);
        uint256 beforeUser2Transfer = testToken.balanceOf(user2);
        uint256 transferAmount = 30 * TOKEN_PRECISION;
        vm.prank(user1);
        testToken.approve(address(this), transferAmount);
        testToken.transferFrom(user1, user2, transferAmount);
        uint256 afterUser1Transfer = testToken.balanceOf(user1);
        uint256 afterUser2Transfer = testToken.balanceOf(user2);
        assertEq(afterUser1Transfer, mintAmount - transferAmount);
        assertEq(afterUser2Transfer, transferAmount);
        assertEq(beforeUser1Transfer + beforeUser2Transfer, afterUser1Transfer + afterUser2Transfer);
    }

    /*//////////////////////////////////////////////////////////////
                    ERC20Permit Impelmentation
    //////////////////////////////////////////////////////////////*/

    function testPermitIsCorrect() external {
        uint256 duration = block.timestamp;
        uint256 deadline = duration + 1000;
        uint256 approvedAmount = 60 * TOKEN_PRECISION;
        uint256 nonce = swapV2ERC20.nonces(user1);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(
                    abi.encode(
                        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                        keccak256(bytes("Myswap V2")),
                        keccak256(bytes("1")),
                        block.chainid,
                        address(swapV2ERC20)
                    )
                ),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)"),
                        user1,
                        address(this),
                        approvedAmount,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privatekey1, digest);
        vm.expectRevert("MyswapV2: Permit Expired");
        swapV2ERC20.permit(user1, address(this), approvedAmount, block.timestamp - 1, v, r, s);
        vm.expectRevert("INVALID_SIGNER");
        swapV2ERC20.permit(user2, address(this), approvedAmount, deadline, v, r, s);

        swapV2ERC20.permit(user1, address(this), approvedAmount, deadline, v, r, s);
        uint256 actualApprovedAmount = swapV2ERC20.allowance(user1, address(this));
        console2.log("expected Approved Amount: ", approvedAmount);
        console2.log("actually Approved Amount: ", actualApprovedAmount);
        assertEq(approvedAmount, actualApprovedAmount);
    }

    function testDOMAIN_SEPARATOR() external view {
        bytes32 expectDomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Myswap V2")),
                keccak256(bytes("1")),
                block.chainid,
                address(swapV2ERC20)
            )
        );

        bytes32 actualDomainSeparator = swapV2ERC20.DOMAIN_SEPARATOR();
        assertEq(expectDomainSeparator, actualDomainSeparator);
    }
}

/*//////////////////////////////////////////////////////////////
                 ERC20 MINT AND BURN Helper
//////////////////////////////////////////////////////////////*/
contract TestToken is MyswapV2ERC20 {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
