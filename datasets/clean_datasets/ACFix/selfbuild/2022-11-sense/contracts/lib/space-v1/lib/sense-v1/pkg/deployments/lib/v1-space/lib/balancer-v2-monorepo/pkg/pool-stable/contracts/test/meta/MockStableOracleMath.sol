pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/test/MockLogCompression.sol";
import "../../meta/StableOracleMath.sol";
contract MockStableOracleMath is StableOracleMath, MockLogCompression {
    function calcLogSpotPrice(
        uint256 amplificationParameter,
        uint256[] memory balances
    ) external pure returns (int256) {
        uint256 spotPrice = StableOracleMath._calcSpotPrice(amplificationParameter, balances[0], balances[1]);
        return LogCompression.toLowResLog(spotPrice);
    }
    function calcLogBptPrice(
        uint256 amplificationParameter,
        uint256[] memory balances,
        int256 bptTotalSupplyLn
    ) external pure returns (int256) {
        uint256 spotPrice = StableOracleMath._calcSpotPrice(amplificationParameter, balances[0], balances[1]);
        return StableOracleMath._calcLogBptPrice(spotPrice, balances[0], balances[1], bptTotalSupplyLn);
    }
}