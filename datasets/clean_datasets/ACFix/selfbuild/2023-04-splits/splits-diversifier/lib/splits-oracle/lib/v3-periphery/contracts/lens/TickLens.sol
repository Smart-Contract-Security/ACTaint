pragma solidity >=0.5.0;
pragma abicoder v2;
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '../interfaces/ITickLens.sol';
contract TickLens is ITickLens {
    function getPopulatedTicksInWord(address pool, int16 tickBitmapIndex)
        public
        view
        override
        returns (PopulatedTick[] memory populatedTicks)
    {
        uint256 bitmap = IUniswapV3Pool(pool).tickBitmap(tickBitmapIndex);
        unchecked {
            uint256 numberOfPopulatedTicks;
            for (uint256 i = 0; i < 256; i++) {
                if (bitmap & (1 << i) > 0) numberOfPopulatedTicks++;
            }
            int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();
            populatedTicks = new PopulatedTick[](numberOfPopulatedTicks);
            for (uint256 i = 0; i < 256; i++) {
                if (bitmap & (1 << i) > 0) {
                    int24 populatedTick = ((int24(tickBitmapIndex) << 8) + int24(uint24(i))) * tickSpacing;
                    (uint128 liquidityGross, int128 liquidityNet, , , , , , ) = IUniswapV3Pool(pool).ticks(
                        populatedTick
                    );
                    populatedTicks[--numberOfPopulatedTicks] = PopulatedTick({
                        tick: populatedTick,
                        liquidityNet: liquidityNet,
                        liquidityGross: liquidityGross
                    });
                }
            }
        }
    }
}