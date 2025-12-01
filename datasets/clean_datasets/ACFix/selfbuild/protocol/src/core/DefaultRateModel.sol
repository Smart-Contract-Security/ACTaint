pragma solidity ^0.8.17;
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IRateModel} from "../interface/core/IRateModel.sol";
import {Errors} from "../utils/Errors.sol";
contract DefaultRateModel is IRateModel {
    using FixedPointMathLib for uint;
    uint immutable c1;
    uint immutable c2;
    uint immutable c3;
    uint immutable secsPerYear;
    uint constant SCALE = 1e18;
    constructor(uint _c1, uint _c2, uint _c3, uint _secsPerYear) {
        if (_c1 == 0 || _c2 == 0 || _c3 == 0 || _secsPerYear == 0)
            revert Errors.IncorrectConstructorArgs();
        c1 = _c1;
        c2 = _c2;
        c3 = _c3;
        secsPerYear = _secsPerYear;
    }
    function getBorrowRatePerSecond(
        uint liquidity,
        uint borrows
    )
        external
        view
        returns (uint)
    {
        uint util = _utilization(liquidity, borrows);
        return c3.mulDivDown(
            (
                util.mulWadDown(c1)
                + util.rpow(32, SCALE).mulWadDown(c1)
                + util.rpow(64, SCALE).mulWadDown(c2)
            ),
            secsPerYear
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