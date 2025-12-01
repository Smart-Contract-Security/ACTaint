pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
interface ICurveTriCryptoOracle {
    function lp_price() external view returns (uint256);
}
interface ICurvePool {
    function price_oracle(uint256) external view returns (uint256);
}
contract CurveTriCryptoOracle is IOracle {
    ICurveTriCryptoOracle immutable curveTriCryptoOracle;
    ICurvePool immutable pool;
    constructor(ICurveTriCryptoOracle _curveTriCryptoOracle, ICurvePool _pool) {
        curveTriCryptoOracle = _curveTriCryptoOracle;
        pool = _pool;
    }
    function getPrice(address) external view returns (uint) {
        return curveTriCryptoOracle.lp_price() * 1e18 / pool.price_oracle(1);
    }
}