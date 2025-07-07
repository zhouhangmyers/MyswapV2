# 定义添加流动性的持有证明LP-Token合约行为

这是一个 **ERC20 token 的实现合约**，被 `UniswapV2Pair` 继承，用来管理：

- LP token 的精度（decimals = 18）
- LP token 的名称和符号
- `mint()` 和 `burn()` 权限控制（只有 Pair 合约能调用）
- `permit()`（EIP-2612 支持）

## 1,定义接口，声名行为规范。

![image-20250629144228278](F:\solidity\note\src\image-20250629144228278.png)

