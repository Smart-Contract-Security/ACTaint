pragma solidity =0.8.12;
import {Tick} from '../libraries/Tick.sol';
import {TickMath} from '../libraries/TickMath.sol';
contract TickEchidnaTest {
    function checkTickSpacingToParametersInvariants(int24 tickSpacing) external pure {
        require(tickSpacing <= TickMath.MAX_TICK);
        require(tickSpacing > 0);
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint128 maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(tickSpacing);
        assert(maxTick == -minTick);
        assert(maxTick > 0);
        assert((maxTick - minTick) % tickSpacing == 0);
        uint256 numTicks = uint256(int256((maxTick - minTick) / tickSpacing)) + 1;
        assert(uint256(maxLiquidityPerTick) * numTicks <= type(uint128).max);
    }
}