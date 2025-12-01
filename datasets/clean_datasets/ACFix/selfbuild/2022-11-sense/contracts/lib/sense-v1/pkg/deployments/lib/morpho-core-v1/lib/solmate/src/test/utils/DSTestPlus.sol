pragma solidity >=0.8.0;
import {DSTest} from "ds-test/test.sol";
import {Hevm} from "./Hevm.sol";
contract DSTestPlus is DSTest {
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    address internal constant DEAD_ADDRESS = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
    string private checkpointLabel;
    uint256 private checkpointGasLeft = 1; 
    function startMeasuringGas(string memory label) internal virtual {
        checkpointLabel = label;
        checkpointGasLeft = gasleft();
    }
    function stopMeasuringGas() internal virtual {
        uint256 checkpointGasLeft2 = gasleft();
        uint256 gasDelta = checkpointGasLeft - checkpointGasLeft2 - 100;
        emit log_named_uint(string(abi.encodePacked(checkpointLabel, " Gas")), gasDelta);
    }
    function fail(string memory err) internal virtual {
        emit log_named_string("Error", err);
        fail();
    }
    function assertFalse(bool data) internal virtual {
        assertTrue(!data);
    }
    function assertUint128Eq(uint128 a, uint128 b) internal virtual {
        assertEq(uint256(a), uint256(b));
    }
    function assertUint64Eq(uint64 a, uint64 b) internal virtual {
        assertEq(uint256(a), uint256(b));
    }
    function assertUint96Eq(uint96 a, uint96 b) internal virtual {
        assertEq(uint256(a), uint256(b));
    }
    function assertUint32Eq(uint32 a, uint32 b) internal virtual {
        assertEq(uint256(a), uint256(b));
    }
    function assertBoolEq(bool a, bool b) internal virtual {
        b ? assertTrue(a) : assertFalse(a);
    }
    function assertApproxEq(
        uint256 a,
        uint256 b,
        uint256 maxDelta
    ) internal virtual {
        uint256 delta = a > b ? a - b : b - a;
        if (delta > maxDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("  Expected", b);
            emit log_named_uint("    Actual", a);
            emit log_named_uint(" Max Delta", maxDelta);
            emit log_named_uint("     Delta", delta);
            fail();
        }
    }
    function assertRelApproxEq(
        uint256 a,
        uint256 b,
        uint256 maxPercentDelta
    ) internal virtual {
        uint256 delta = a > b ? a - b : b - a;
        uint256 abs = a > b ? a : b;
        uint256 percentDelta = (delta * 1e18) / abs;
        if (percentDelta > maxPercentDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_uint("    Expected", b);
            emit log_named_uint("      Actual", a);
            emit log_named_uint(" Max % Delta", maxPercentDelta);
            emit log_named_uint("     % Delta", percentDelta);
            fail();
        }
    }
    function assertBytesEq(bytes memory a, bytes memory b) internal virtual {
        if (keccak256(a) != keccak256(b)) {
            emit log("Error: a == b not satisfied [bytes]");
            emit log_named_bytes("  Expected", b);
            emit log_named_bytes("    Actual", a);
            fail();
        }
    }
    function assertUintArrayEq(uint256[] memory a, uint256[] memory b) internal virtual {
        require(a.length == b.length, "LENGTH_MISMATCH");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }
    function bound(
        uint256 x,
        uint256 min,
        uint256 max
    ) internal pure returns (uint256 result) {
        require(max >= min, "MAX_LESS_THAN_MIN");
        uint256 size = max - min;
        if (max != type(uint256).max) size++; 
        if (size == 0) return min; 
        if (max == type(uint256).max && x != 0) x--; 
        if (x < min) x += size * (((min - x) / size) + 1);
        result = min + ((x - min) % size);
        if (max == type(uint256).max && x != 0) result++;
    }
    function min3(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256) {
        return a > b ? (b > c ? c : b) : (a > c ? c : a);
    }
    function min2(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? b : a;
    }
}