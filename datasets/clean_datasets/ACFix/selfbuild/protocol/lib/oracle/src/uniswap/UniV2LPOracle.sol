pragma solidity ^0.8.17;
import {IERC20} from "../utils/IERC20.sol";
import {IOracle} from "../core/IOracle.sol";
import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
contract UniV2LpOracle is IOracle {
    using FixedPointMathLib for uint;
    IOracle public immutable oracle;
    constructor(IOracle _oracle) {
        oracle = _oracle;
    }
    function getPrice(address pair) external view returns (uint) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        (uint r0, uint r1,) = IUniswapV2Pair(pair).getReserves();
        uint decimals0 = IERC20(token0).decimals();
        uint decimals1 = IERC20(token1).decimals();
        if (decimals0 <= 18)
            r0 = r0 * 10 ** (18 - decimals0);
        else r0 = r0 / 10 ** (decimals0 - 18);
        if (decimals1 <= 18)
            r1 = r1 * 10 ** (18 - decimals1);
        else r1 = r1 / 10 ** (decimals1 - 18);
        return FixedPointMathLib.sqrt(
            r0
            .mulWadDown(r1)
            .mulWadDown(oracle.getPrice(token0))
            .mulWadDown(oracle.getPrice(token1))
        ).mulDivDown(2e27, IUniswapV2Pair(pair).totalSupply());
    }
}