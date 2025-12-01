pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/LogCompression.sol";
contract WeightedOracleMath {
    using FixedPoint for uint256;
    function _calcLogSpotPrice(
        uint256 normalizedWeightA,
        uint256 balanceA,
        uint256 normalizedWeightB,
        uint256 balanceB
    ) internal pure returns (int256) {
        uint256 spotPrice = balanceA.divUp(normalizedWeightA).divUp(balanceB.divUp(normalizedWeightB));
        return LogCompression.toLowResLog(spotPrice);
    }
    function _calcLogBPTPrice(
        uint256 normalizedWeight,
        uint256 balance,
        int256 logBptTotalSupply
    ) internal pure returns (int256) {
        uint256 balanceOverWeight = balance.divUp(normalizedWeight);
        int256 logBalanceOverWeight = LogCompression.toLowResLog(balanceOverWeight);
        return logBalanceOverWeight - logBptTotalSupply;
    }
}