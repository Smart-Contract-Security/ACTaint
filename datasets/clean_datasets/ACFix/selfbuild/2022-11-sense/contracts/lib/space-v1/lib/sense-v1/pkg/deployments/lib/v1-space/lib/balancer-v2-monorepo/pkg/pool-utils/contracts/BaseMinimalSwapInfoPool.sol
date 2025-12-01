pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./BasePool.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IMinimalSwapInfoPool.sol";
abstract contract BaseMinimalSwapInfoPool is IMinimalSwapInfoPool, BasePool {
    function onSwap(
        SwapRequest memory request,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) public virtual override onlyVault(request.poolId) returns (uint256) {
        uint256 scalingFactorTokenIn = _scalingFactor(request.tokenIn);
        uint256 scalingFactorTokenOut = _scalingFactor(request.tokenOut);
        if (request.kind == IVault.SwapKind.GIVEN_IN) {
            uint256 amountInMinusSwapFees = _subtractSwapFeeAmount(request.amount);
            uint256 swapFee = request.amount - amountInMinusSwapFees;
            _processSwapFeeAmount(request.tokenIn, _upscale(swapFee, scalingFactorTokenIn));
            request.amount = amountInMinusSwapFees;
            balanceTokenIn = _upscale(balanceTokenIn, scalingFactorTokenIn);
            balanceTokenOut = _upscale(balanceTokenOut, scalingFactorTokenOut);
            request.amount = _upscale(request.amount, scalingFactorTokenIn);
            uint256 amountOut = _onSwapGivenIn(request, balanceTokenIn, balanceTokenOut);
            return _downscaleDown(amountOut, scalingFactorTokenOut);
        } else {
            balanceTokenIn = _upscale(balanceTokenIn, scalingFactorTokenIn);
            balanceTokenOut = _upscale(balanceTokenOut, scalingFactorTokenOut);
            request.amount = _upscale(request.amount, scalingFactorTokenOut);
            uint256 amountIn = _onSwapGivenOut(request, balanceTokenIn, balanceTokenOut);
            amountIn = _downscaleUp(amountIn, scalingFactorTokenIn);
            uint256 amountInPlusSwapFees = _addSwapFeeAmount(amountIn);
            uint256 swapFee = amountInPlusSwapFees - amountIn;
            _processSwapFeeAmount(request.tokenIn, _upscale(swapFee, scalingFactorTokenIn));
            return amountInPlusSwapFees;
        }
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) internal virtual returns (uint256);
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) internal virtual returns (uint256);
    function _processSwapFeeAmount(
        uint256, 
        uint256 
    ) internal virtual {}
    function _processSwapFeeAmount(IERC20 token, uint256 amount) internal {
        _processSwapFeeAmount(_tokenAddressToIndex(token), amount);
    }
    function _processSwapFeeAmounts(uint256[] memory amounts) internal {
        InputHelpers.ensureInputLengthMatch(amounts.length, _getTotalTokens());
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            _processSwapFeeAmount(i, amounts[i]);
        }
    }
    function _tokenAddressToIndex(
        IERC20 
    ) internal view virtual returns (uint256) {
        return 0;
    }
}