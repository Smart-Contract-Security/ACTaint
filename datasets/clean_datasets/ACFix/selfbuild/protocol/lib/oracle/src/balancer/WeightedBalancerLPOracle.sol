pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
import {IERC20} from "../utils/IERC20.sol";
import {IVault} from "./IVault.sol";
import {IPool} from "./IPool.sol";
import {FixedPoint} from "./library/FixedPoint.sol";
contract WeightedBalancerLPOracle is IOracle {
    using FixedPoint for uint;
    IVault immutable vault;
    IOracle immutable oracleFacade;
    constructor(IOracle _oracle, IVault _vault) {
        vault = _vault;
        oracleFacade = _oracle;
    }
    function getPrice(address token) external view returns (uint) {
        (
            address[] memory poolTokens,
            uint256[] memory balances,
        ) = vault.getPoolTokens(IPool(token).getPoolId());
        uint256[] memory weights = IPool(token).getNormalizedWeights();
        uint length = weights.length;
        uint temp = 1e18;
        uint invariant = 1e18;
        for(uint i; i < length; i++) {
            temp = temp.mulDown(
                (oracleFacade.getPrice(poolTokens[i]).divDown(weights[i]))
                .powDown(weights[i])
            );
            invariant = invariant.mulDown(
                (balances[i] * 10 ** (18 - IERC20(poolTokens[i]).decimals()))
                .powDown(weights[i])
            );
        }
        return invariant
            .mulDown(temp)
            .divDown(IPool(token).totalSupply());
    }
}