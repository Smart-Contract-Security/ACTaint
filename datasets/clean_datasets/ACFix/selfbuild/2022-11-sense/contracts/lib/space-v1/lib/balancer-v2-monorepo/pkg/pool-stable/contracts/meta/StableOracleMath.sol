pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/LogCompression.sol";
import "../StableMath.sol";
contract StableOracleMath is StableMath {
    using FixedPoint for uint256;
    function _calcLogPrices(
        uint256 amplificationParameter,
        uint256 balanceX,
        uint256 balanceY,
        int256 logBptTotalSupply
    ) internal pure returns (int256 logSpotPrice, int256 logBptPrice) {
        uint256 spotPrice = _calcSpotPrice(amplificationParameter, balanceX, balanceY);
        logBptPrice = _calcLogBptPrice(spotPrice, balanceX, balanceY, logBptTotalSupply);
        logSpotPrice = LogCompression.toLowResLog(spotPrice);
    }
    function _calcSpotPrice(
        uint256 amplificationParameter,
        uint256 balanceX,
        uint256 balanceY
    ) internal pure returns (uint256) {
        uint256 invariant = _calculateInvariant(amplificationParameter, _balances(balanceX, balanceY), true);
        uint256 a = (amplificationParameter * 2) / _AMP_PRECISION;
        uint256 b = Math.mul(invariant, a).sub(invariant);
        uint256 axy2 = Math.mul(a * 2, balanceX).mulDown(balanceY); 
        uint256 derivativeX = axy2.add(Math.mul(a, balanceY).mulDown(balanceY)).sub(b.mulDown(balanceY));
        uint256 derivativeY = axy2.add(Math.mul(a, balanceX).mulDown(balanceX)).sub(b.mulDown(balanceX));
        return derivativeX.divUp(derivativeY);
    }
    function _calcLogBptPrice(
        uint256 spotPrice,
        uint256 balanceX,
        uint256 balanceY,
        int256 logBptTotalSupply
    ) internal pure returns (int256) {
        uint256 totalBalanceX = balanceX.add(spotPrice.mulUp(balanceY));
        int256 logTotalBalanceX = LogCompression.toLowResLog(totalBalanceX);
        return logTotalBalanceX - logBptTotalSupply;
    }
    function _balances(uint256 balanceX, uint256 balanceY) private pure returns (uint256[] memory balances) {
        balances = new uint256[](2);
        balances[0] = balanceX;
        balances[1] = balanceY;
    }
}