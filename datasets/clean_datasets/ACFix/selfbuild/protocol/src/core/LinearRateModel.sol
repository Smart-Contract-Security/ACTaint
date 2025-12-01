pragma solidity ^0.8.17;
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IRateModel} from "../interface/core/IRateModel.sol";
contract LinearRateModel is IRateModel {
    using FixedPointMathLib for uint;
    uint public immutable baseRate;
    uint public immutable slope1;
    uint public immutable slope2;
    uint public immutable OPTIMAL_USAGE_RATIO;
    uint public immutable MAX_EXCESS_USAGE_RATIO;
    uint immutable secsPerYear;
    constructor(
        uint _baseRate,
        uint _slope1,
        uint _slope2,
        uint _optimalUsageRatio,
        uint _maxExcessUsageRatio,
        uint _secsPerYear
    )
    {
        baseRate = _baseRate;
        slope1 = _slope1;
        slope2 = _slope2;
        OPTIMAL_USAGE_RATIO = _optimalUsageRatio;
        MAX_EXCESS_USAGE_RATIO = _maxExcessUsageRatio;
        secsPerYear = _secsPerYear;
    }
    function getBorrowRatePerSecond(
        uint liquidity,
        uint totalDebt
    )
        external
        view
        returns (uint)
    {
        uint utilization = _utilization(liquidity, totalDebt);
        if (utilization > OPTIMAL_USAGE_RATIO) {
            return (
                baseRate + slope1 + slope2.mulWadDown(
                    getExcessBorrowUsage(utilization)
                )
            ).divWadDown(secsPerYear);
        } else {
            return (
                baseRate + slope1.mulDivDown(utilization, OPTIMAL_USAGE_RATIO)
            ).divWadDown(secsPerYear);
        }
    }
    function getExcessBorrowUsage(uint utilization)
        internal
        view
        returns (uint)
    {
        return (utilization - OPTIMAL_USAGE_RATIO).divWadDown(
            MAX_EXCESS_USAGE_RATIO
        );
    }
    function _utilization(uint liquidity, uint borrows)
        internal
        pure
        returns (uint)
    {
        uint totalAssets = liquidity + borrows;
        return (totalAssets == 0) ? 0 : borrows.divWadDown(totalAssets);
    }
}