// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IMyswapV2Pair} from "./interfaces/IMyswapV2Pair.sol";
import {MyswapV2ERC20} from "./MyswapV2ERC20.sol";
import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IMyswapV2Factory} from "./interfaces/IMyswapV2Factory.sol";
import {IMyswapV2Callee} from "./interfaces/IMyswapV2Callee.sol";

import {Math} from "@openzeppelin-contracts/contracts/utils/math/Math.sol";
/**
 * @title Modern UniswapV2 Rewrite | 现代uniswapv2重写
 * @author @zhouhangmyers | 周航
 * @notice A complete reimplementation of the Uniswap V2 protocol using Solidity ^0.8.26.| 一个使用Solidity ^0.8.26完全重新实现的Uniswap V2协议。
 * @dev This project is independently written from scratch without forking the original codebase. | 该项目完全独立编写，未从原始代码库进行分支。
 */

contract MyswapV2Pair is IMyswapV2Pair, MyswapV2ERC20 {
    using Math for uint256;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(abi.encodePacked("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 private unlocked = 1;

    constructor() {
        factory = msg.sender;
    }

    modifier lock() {
        require(unlocked == 1, "myswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "MyswapV2: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /*//////////////////////////////////////////////////////////////
                        MINT BURN SWAP SKIM SYNC
    //////////////////////////////////////////////////////////////*/

    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * totalSupply / _reserve1);
        }
        //require(liquidity > 0) 的作用是
        //1.防止在初始阶段创建无意义的、极小规模的流动性池
        //2.保护用户在向大型池添加“粉尘”级别的流动性时，不会因为计算精度问题而白白浪费Gas费
        require(liquidity > 0, "MyswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);

        ////////////////////////////////////////////////重点//////////////////////
        //我之前写的uint256(reserve0*reserve1)是错误的，uint112*uint112已经溢出
        if (feeOn) kLast = uint256(reserve0) * uint256(reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;

        //balance 代表了池子“当前真实的总资产”，而 reserve 仅仅是“上一次结算时的资产快照”。它们之间的差值，就是这段时间累积的交易手续费。使用 balance 是为了确保流动性提供者（LP）在退出时，能公平地按比例分走他们应得的本金 + 手续费。
        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "MyswapV2: INSUFFICIENT_LIQUIDITY_BURND");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "MyswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "MyswapV2: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "MyswapV2: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) IMyswapV2Callee(to).myswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // balance0 : 当前合约地址里实实在在的代币余额
        // _reserve0: 上次状态同步时记录的资产快照
        //balance0 和 _reserve0之间的差值，主要是这段时间累积的交易手续费。

        //换句话说用户用token0 换 token1，理论上要额外手续费的部分，然后balance0是增加的,amount0Out为0，所以公式成立。这时token1是要发送出去的，balance1是实时的，所以balance1==上一次快照的数量-发送出去的数量，amount1In = 0;
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "MyswapV2: INSUFFICIENT_INPUT_AMOUNT");
        {
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 1000 ** 2, "MyswapV2: K");
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1Out, amount0Out, amount1Out, to);
    }

    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "MyswapV2: TRANSFER_FAILED");
    }

    function encode(uint112 y) private pure returns (uint224 z) {
        z = uint224(y) * 2 ** 112;
    }

    function updiv(uint224 x, uint112 y) private pure returns (uint224 z) {
        z = x / uint224(y);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "MyswapV2: OVERFLOW");
        //先取模，再截断，让时间戳每过2的32次方秒，约等于136年，归0重新计算。
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);

        unchecked {
            //允许溢出是为了计算差值，这是可行的
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;

            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                //注意：这一块使用了定点112*112的格式，为了防止精度问题，多乘以了2**112的值，在前端时计算TWAP需要/2**112
                //这也是允许溢出的，也是为了计算price0Cumulative 与 price0CumulativeLast之间的价格差
                price0CumulativeLast += uint256(updiv(encode(_reserve1), reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(updiv(encode(_reserve0), reserve1)) * timeElapsed;
            }
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    //_mintFee的作用是，判断协议是否开启收手续费功能，如果没有开启，就判断有没有保存上一次的底池资产，如果有，就清0，如果不清0，会导致开启协议受手续费的时候，将当前底池的资产减去保留的这个底池资产，如果大于0，会导致灾难性结果，这个值的1/6会铸造成LPtoken给协议，这是灾难性的。我们要知道这个1/6的LPtoken铸造是每当有人触发添加或移除流动性函数时，会优先处理sqrt(kLast)(上一次添加/移除流动性后记录的交易对资产)与当前交易对资产sqrt(reserve0*reserve1)之间的差值，如果后者大于前者，就铸造totalSupply*这个差值/(5sqrt(reserve0*reserve1)+sqrt(kLast))数量的Lptoken给协议方
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IMyswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            //如果开启收费，并且_KLast不为空，表示这是自开启收费后第二次起添加流动性就开始收费，
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootkLast = Math.sqrt(_kLast);
                if (rootK > rootkLast) {
                    uint256 numerator = totalSupply * (rootK - rootkLast);
                    uint256 denominator = rootK * 5 + rootkLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
}
