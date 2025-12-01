pragma solidity ^0.8.19;
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
library ScalingUtils {
    using MathUpgradeable for uint256;
    uint256 internal constant ONE = 1e18;
    function scaleByDecimals(uint256 sourceValue, uint8 sourceDecimals, uint8 targetDecimals)
        internal
        pure
        returns (uint256)
    {
        if (targetDecimals >= sourceDecimals) {
            return sourceValue * (10 ** (targetDecimals - sourceDecimals));
        } else {
            return sourceValue / (10 ** (sourceDecimals - targetDecimals));
        }
    }
    function scaleByDecimals(
        uint256 sourceValue,
        uint8 sourceDecimals,
        uint8 targetDecimals,
        MathUpgradeable.Rounding rounding
    ) internal pure returns (uint256) {
        return scaleByBases(sourceValue, 10 ** sourceDecimals, 10 ** targetDecimals, rounding);
    }
    function scaleByBases(uint256 sourceValue, uint256 sourceBase, uint256 targetBase)
        internal
        pure
        returns (uint256)
    {
        if (targetBase >= sourceBase) {
            return sourceValue * (targetBase / sourceBase);
        } else {
            return sourceValue / (sourceBase / targetBase);
        }
    }
    function scaleByBases(
        uint256 sourceValue,
        uint256 sourceBase,
        uint256 targetBase,
        MathUpgradeable.Rounding rounding
    ) internal pure returns (uint256) {
        return sourceValue.mulDiv(targetBase, sourceBase, rounding);
    }
}