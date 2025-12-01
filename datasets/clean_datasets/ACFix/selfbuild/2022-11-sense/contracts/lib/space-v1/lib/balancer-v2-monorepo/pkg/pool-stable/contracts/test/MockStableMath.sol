pragma solidity ^0.7.0;
import "../StableMath.sol";
contract MockStableMath is StableMath {
    function invariant(uint256 amp, uint256[] memory balances, bool roundUp) external pure returns (uint256) {
        return _calculateInvariant(amp, balances, roundUp);
    }
    function outGivenIn(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountIn
    ) external pure returns (uint256) {
        return _calcOutGivenIn(amp, balances, tokenIndexIn, tokenIndexOut, tokenAmountIn);
    }
    function inGivenOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountOut
    ) external pure returns (uint256) {
        return _calcInGivenOut(amp, balances, tokenIndexIn, tokenIndexOut, tokenAmountOut);
    }
    function exactTokensInForBPTOut(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsIn,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        return _calcBptOutGivenExactTokensIn(amp, balances, amountsIn, bptTotalSupply, swapFee);
    }
    function tokenInForExactBPTOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountOut,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        return _calcTokenInGivenExactBptOut(amp, balances, tokenIndex, bptAmountOut, bptTotalSupply, swapFee);
    }
    function exactBPTInForTokenOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        return _calcTokenOutGivenExactBptIn(amp, balances, tokenIndex, bptAmountIn, bptTotalSupply, swapFee);
    }
    function exactBPTInForTokensOut(
        uint256[] memory balances,
        uint256 bptAmountIn,
        uint256 bptTotalSupply
    ) external pure returns (uint256[] memory) {
        return _calcTokensOutGivenExactBptIn(balances, bptAmountIn, bptTotalSupply);
    }
    function bptInForExactTokensOut(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsOut,
        uint256 bptTotalSupply,
        uint256 swapFee
    ) external pure returns (uint256) {
        return _calcBptInGivenExactTokensOut(amp, balances, amountsOut, bptTotalSupply, swapFee);
    }
    function calculateDueTokenProtocolSwapFeeAmount(
        uint256 amp,
        uint256[] memory balances,
        uint256 lastInvariant,
        uint256 tokenIndex,
        uint256 protocolSwapFeePercentage
    ) external pure returns (uint256) {
        return _calcDueTokenProtocolSwapFeeAmount(amp, balances, lastInvariant, tokenIndex, protocolSwapFeePercentage);
    }
}