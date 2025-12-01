pragma solidity ^0.8.11;
interface IQuoter {
  function quoteExactInput(bytes memory path, uint256 amountIn)
    external
    returns (uint256 amountOut);
  function quoteExactInputSingle(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn,
    uint160 sqrtPriceLimitX96
  ) external returns (uint256 amountOut);
}