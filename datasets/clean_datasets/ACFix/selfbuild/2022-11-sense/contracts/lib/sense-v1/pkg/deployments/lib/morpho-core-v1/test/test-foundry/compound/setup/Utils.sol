pragma solidity 0.8.13;
import "@contracts/compound/libraries/CompoundMath.sol";
import "forge-std/Test.sol";
contract Utils is Test {
    using CompoundMath for uint256;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant PERCENT_BASE = 10000;
    function to6Decimals(uint256 value) internal pure returns (uint256) {
        return value / 1e12;
    }
    function to8Decimals(uint256 value) internal pure returns (uint256) {
        return value / 1e10;
    }
    function getAbsDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a - b;
        }
        return b - a;
    }
    function testEquality(uint256 _firstValue, uint256 _secondValue) internal {
        assertApproxEqAbs(_firstValue, _secondValue, 20);
    }
    function testEquality(
        uint256 _firstValue,
        uint256 _secondValue,
        string memory err
    ) internal {
        assertApproxEqAbs(_firstValue, _secondValue, 20, err);
    }
    function testEqualityLarge(uint256 _firstValue, uint256 _secondValue) internal {
        assertApproxEqAbs(_firstValue, _secondValue, 1e16);
    }
    function testEqualityLarge(
        uint256 _firstValue,
        uint256 _secondValue,
        string memory err
    ) internal {
        assertApproxEqAbs(_firstValue, _secondValue, 1e16, err);
    }
    function getBalanceOnCompound(uint256 _amountInUnderlying, uint256 _rate)
        internal
        pure
        returns (uint256)
    {
        uint256 cTokenAmount = (_amountInUnderlying * 1e18) / _rate;
        return ((cTokenAmount * _rate) / 1e18);
    }
    function _computeCompoundedInterest(uint256 _rate, uint256 _elapsedBlocks)
        internal
        pure
        returns (uint256)
    {
        if (_elapsedBlocks == 0) return WAD;
        if (_elapsedBlocks == 1) return WAD + _rate;
        uint256 ratePowerTwo = _rate.mul(_rate);
        uint256 ratePowerThree = ratePowerTwo.mul(_rate);
        return
            WAD +
            _rate *
            _elapsedBlocks +
            (_elapsedBlocks * (_elapsedBlocks - 1) * ratePowerTwo) /
            2 +
            (_elapsedBlocks * (_elapsedBlocks - 1) * (_elapsedBlocks - 2) * ratePowerThree) /
            6;
    }
    function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }
}