// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author HangZhou | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

interface IMyswapV2ERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // metadata
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // ERC20 standard
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // ERC20 Permit
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
}
