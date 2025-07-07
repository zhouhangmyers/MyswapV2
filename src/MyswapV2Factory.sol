// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IMyswapV2Factory} from "./interfaces/IMyswapV2Factory.sol";
import {MyswapV2Pair} from "./MyswapV2Pair.sol";
import {IMyswapV2Pair} from "./interfaces/IMyswapV2Pair.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author HangZhou | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract MyswapV2Factory is IMyswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "MyswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "MyswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "MyswapV2: IDENTICA_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "MyswapV2: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "MyswapV2: PAIR_EXISTS");
        bytes memory bytecode = type(MyswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        IMyswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
