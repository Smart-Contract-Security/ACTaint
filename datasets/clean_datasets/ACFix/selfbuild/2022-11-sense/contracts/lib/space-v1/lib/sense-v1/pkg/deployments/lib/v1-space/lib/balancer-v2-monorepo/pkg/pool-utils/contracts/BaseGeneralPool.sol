pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./BasePool.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IGeneralPool.sol";
abstract contract BaseGeneralPool is IGeneralPool, BasePool {
    function onSwap(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) public virtual override onlyVault(swapRequest.poolId) returns (uint256) {
        _validateIndexes(indexIn, indexOut, _getTotalTokens());
        uint256[] memory scalingFactors = _scalingFactors();
        return
            swapRequest.kind == IVault.SwapKind.GIVEN_IN
                ? _swapGivenIn(swapRequest, balances, indexIn, indexOut, scalingFactors)
                : _swapGivenOut(swapRequest, balances, indexIn, indexOut, scalingFactors);
    }
    function _swapGivenIn(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut,
        uint256[] memory scalingFactors
    ) internal returns (uint256) {
        swapRequest.amount = _subtractSwapFeeAmount(swapRequest.amount);
        _upscaleArray(balances, scalingFactors);
        swapRequest.amount = _upscale(swapRequest.amount, scalingFactors[indexIn]);
        uint256 amountOut = _onSwapGivenIn(swapRequest, balances, indexIn, indexOut);
        return _downscaleDown(amountOut, scalingFactors[indexOut]);
    }
    function _swapGivenOut(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut,
        uint256[] memory scalingFactors
    ) internal returns (uint256) {
        _upscaleArray(balances, scalingFactors);
        swapRequest.amount = _upscale(swapRequest.amount, scalingFactors[indexOut]);
        uint256 amountIn = _onSwapGivenOut(swapRequest, balances, indexIn, indexOut);
        amountIn = _downscaleUp(amountIn, scalingFactors[indexIn]);
        return _addSwapFeeAmount(amountIn);
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) internal virtual returns (uint256);
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) internal virtual returns (uint256);
    function _validateIndexes(
        uint256 indexIn,
        uint256 indexOut,
        uint256 limit
    ) private pure {
        _require(indexIn < limit && indexOut < limit, Errors.OUT_OF_BOUNDS);
    }
}