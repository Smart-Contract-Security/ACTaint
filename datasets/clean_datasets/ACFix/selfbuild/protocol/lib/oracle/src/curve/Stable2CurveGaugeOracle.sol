pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
interface IGauge {
    function lp_token() external view returns (address);
}
contract Stable2CurveGaugeOracle is IOracle {
    IOracle immutable oracleFacade;
    constructor(IOracle _oracle) {
        oracleFacade = _oracle;
    }
    function getPrice(address token) external view returns (uint) {
        return oracleFacade.getPrice(IGauge(token).lp_token());
    }
}