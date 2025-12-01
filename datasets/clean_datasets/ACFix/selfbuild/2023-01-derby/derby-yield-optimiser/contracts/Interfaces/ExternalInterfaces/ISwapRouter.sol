pragma solidity ^0.8.11;
interface ISwapRouter {
  struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
  }
  function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params)
    external
    returns (uint256 amountOut);
  struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
  }
  function exactInput(ExactInputParams calldata params)
    external
    payable
    returns (uint256 amountOut);
}