pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
interface ICurvePool {
    function coins(uint256) external view returns (address);
    function get_virtual_price() external view returns (uint256);
}
contract Stable2CurveOracle is IOracle {
    using FixedPointMathLib for uint;
    IOracle immutable oracleFacade;
    constructor(IOracle _oracle) {
        oracleFacade = _oracle;
    }
    function getPrice(address token) external view returns (uint) {
        uint price0 = oracleFacade.getPrice(ICurvePool(token).coins(0));
        uint price1 = oracleFacade.getPrice(ICurvePool(token).coins(1));
        return ((price0 < price1) ? price0 : price1).mulWadDown(
            ICurvePool(token).get_virtual_price()
        );
    }
}