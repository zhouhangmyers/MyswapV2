// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IMyswapV2ERC20} from "./interfaces/IMyswapV2ERC20.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract MyswapV2ERC20 is IMyswapV2ERC20 {
    /*//////////////////////////////////////////////////////////////
                    ERC20METADATA STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    string public constant name = "Myswap V2";
    string public constant symbol = "MY-V2";
    uint8 public constant decimals = 18;
    /*//////////////////////////////////////////////////////////////
                         ERC20 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    /*//////////////////////////////////////////////////////////////
                      ERC20PERMIT STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    //cast keccak "Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)"
    bytes32 public constant PERMIT_TYPEHASH = 0xfc77c2b9d30fe91687fd39abb7d16fcdfe1472d065740051ab8b13e4bf4a617f;
    mapping(address => uint256) public nonces;

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20PERMIT FUNCTION
    //////////////////////////////////////////////////////////////*/
    function computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        require(block.timestamp <= deadline, "MyswapV2: Permit Expired");

        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, amount, nonces[owner]++, deadline))
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");
            _approve(owner, spender, amount);
        }

        emit Approval(owner, spender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 PRIVATE FUNCTION
    //////////////////////////////////////////////////////////////*/
    function _approve(address owner, address spender, uint256 amount) private {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
    //此函数留作在交易对合约中调用，在交易对合约实现mint和burn，对交易对合约的mint和burn进行访问控制，再调用_mint和_burn实现真正的代币更新
    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC20 EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function GET_INITIAL_CHAIN_ID() external view returns (uint256) {
        return INITIAL_CHAIN_ID;
    }

    function GET_INITIAL_DOMAIN_SEPARATOR() external view returns (bytes32) {
        return INITIAL_DOMAIN_SEPARATOR;
    }
}
