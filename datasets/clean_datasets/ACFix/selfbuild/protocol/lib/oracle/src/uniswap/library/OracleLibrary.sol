pragma solidity ^0.8.17;
import "./TickMath.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "solmate/utils/FixedPointMathLib.sol";
library OracleLibrary {
    function consult(address pool, uint32 secondsAgo)
        internal
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, 'BP');
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(pool).observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];
        arithmeticMeanTick = int24(tickCumulativesDelta / int32(secondsAgo));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(secondsAgo) != 0)) arithmeticMeanTick--;
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FixedPointMathLib.mulDivDown(ratioX192, baseAmount, 1 << 192)
                : FixedPointMathLib.mulDivDown(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FixedPointMathLib.mulDivDown(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FixedPointMathLib.mulDivDown(ratioX128, baseAmount, 1 << 128)
                : FixedPointMathLib.mulDivDown(1 << 128, baseAmount, ratioX128);
        }
    }
}