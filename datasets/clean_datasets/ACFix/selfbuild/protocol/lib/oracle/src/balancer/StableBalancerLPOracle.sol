pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
import {IERC20} from "../utils/IERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IVault} from "./IVault.sol";
import {IPool} from "./IPool.sol";
contract StableBalancerLPOracle is IOracle {
    using FixedPointMathLib for uint;
    IVault immutable vault;
    IOracle immutable oracleFacade;
    constructor(IOracle _oracle, IVault _vault) {
        vault = _vault;
        oracleFacade = _oracle;
    }
    function getPrice(address token) external view returns (uint) {
        (
            address[] memory poolTokens,
            ,
        ) = vault.getPoolTokens(IPool(token).getPoolId());
        uint length = poolTokens.length;
        uint minPrice = oracleFacade.getPrice(poolTokens[0]);
        for(uint i = 1; i < length; i++) {
            uint price = oracleFacade.getPrice(poolTokens[i]);
            minPrice = (price < minPrice) ? price : minPrice;
        }
        return minPrice.mulWadDown(IPool(token).getRate());
    }
}