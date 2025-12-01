pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./interfaces/ISwapFunctions.sol";
import "./utils/Errors.sol";
abstract contract SwapFunctions is ISwapFunctions {
    using MathUpgradeable for uint256;
    function _calculateSwapResult(SwapRequest memory request)
        internal
        view
        virtual
        returns (uint256 amountIn, uint256 amountOut, uint256 fee)
    {
        _validateFeeFraction(request.feeNumerator, request.feeBase);
        if (request.amountType == AmountType.In) {
            return _calculateSwapResultByAmountIn(request);
        } else {
            return _calculateSwapResultByAmountOut(request);
        }
    }
    function _calculateSwapResultByAmountIn(SwapRequest memory request)
        internal
        view
        virtual
        returns (uint256 amountIn, uint256 amountOut, uint256 fee)
    {
        amountIn = request.amount;
        if (request.tokenIn == request.feeToken) {
            fee = _getFeeByAmountWithFee(amountIn, request.feeNumerator, request.feeBase);
            amountOut = _convert(
                request.tokenIn,
                request.tokenOut,
                amountIn - fee,
                MathUpgradeable.Rounding.Down,
                request.price,
                request.priceBase,
                request.quoteToken
            );
        } else {
            amountOut = _convert(
                request.tokenIn,
                request.tokenOut,
                amountIn,
                MathUpgradeable.Rounding.Down,
                request.price,
                request.priceBase,
                request.quoteToken
            );
            fee = _getFeeByAmountWithFee(amountOut, request.feeNumerator, request.feeBase);
            amountOut -= fee;
        }
    }
    function _calculateSwapResultByAmountOut(SwapRequest memory request)
        internal
        view
        virtual
        returns (uint256 amountIn, uint256 amountOut, uint256 fee)
    {
        amountOut = request.amount;
        if (request.tokenIn == request.feeToken) {
            amountIn = _convert(
                request.tokenOut,
                request.tokenIn,
                amountOut,
                MathUpgradeable.Rounding.Up,
                request.price,
                request.priceBase,
                request.quoteToken
            );
            fee = _getFeeByAmountWithoutFee(amountIn, request.feeNumerator, request.feeBase);
            amountIn += fee;
        } else {
            fee = _getFeeByAmountWithoutFee(amountOut, request.feeNumerator, request.feeBase);
            amountIn = _convert(
                request.tokenOut,
                request.tokenIn,
                amountOut + fee,
                MathUpgradeable.Rounding.Up,
                request.price,
                request.priceBase,
                request.quoteToken
            );
        }
    }
    function _validateFeeFraction(uint256 numerator, uint256 denominator) internal view virtual {
        _require((numerator == 0 && denominator == 0) || numerator < denominator, Errors.FEE_FRACTION_INVALID);
    }
    function _getFeeByAmountWithFee(uint256 amount, uint256 feeNumerator, uint256 feeDenominator)
        internal
        view
        virtual
        returns (uint256)
    {
        if (feeDenominator == 0) {
            return 0;
        } else {
            return (amount * feeNumerator).ceilDiv(feeDenominator);
        }
    }
    function _getFeeByAmountWithoutFee(uint256 amount, uint256 feeNumerator, uint256 feeDenominator)
        internal
        view
        virtual
        returns (uint256)
    {
        if (feeDenominator == 0) {
            return 0;
        } else {
            uint256 amountWithFee = (amount * feeDenominator).ceilDiv(feeDenominator - feeNumerator);
            return amountWithFee - amount;
        }
    }
    function _convert(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint256 priceBase,
        address quoteToken
    ) internal view virtual returns (uint256) {
        if (fromToken == toToken) {
            return fromAmount;
        } else if (toToken == quoteToken) {
            return _convertByFromPrice(fromToken, toToken, fromAmount, rounding, price, priceBase);
        } else if (fromToken == quoteToken) {
            return _convertByToPrice(fromToken, toToken, fromAmount, rounding, price, priceBase);
        } else {
            _revert(Errors.PARAMETER_INVALID);
        }
    }
    function _convertByFromPrice(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint256 priceBase
    ) internal view virtual returns (uint256) {
        uint256 fromBase = 10 ** IERC20Metadata(fromToken).decimals();
        uint256 toBase = 10 ** IERC20Metadata(toToken).decimals();
        return fromAmount.mulDiv(price * toBase, priceBase * fromBase, rounding);
    }
    function _convertByToPrice(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint256 priceBase
    ) internal view virtual returns (uint256) {
        uint256 fromBase = 10 ** IERC20Metadata(fromToken).decimals();
        uint256 toBase = 10 ** IERC20Metadata(toToken).decimals();
        return fromAmount.mulDiv(priceBase * toBase, price * fromBase, rounding);
    }
}