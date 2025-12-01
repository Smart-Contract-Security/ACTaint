pragma solidity >=0.5.0;
import {DSTest} from "./test.sol";
contract DemoTest is DSTest {
    function testAssertTrue() public {
        assertTrue(true, "msg");
        assertTrue(true);
    }
    function testFailAssertTrue() public {
        assertTrue(false);
    }
    function testFailAssertTrueWithMsg() public {
        assertTrue(false, "msg");
    }
    function testAssertEqAddr() public {
        assertEq(address(0x0), address(0x0), "msg");
        assertEq(address(0x0), address(0x0));
    }
    function testFailAssertEqAddr() public {
        assertEq(address(0x0), address(0x1));
    }
    function testFailAssertEqAddrWithMsg() public {
        assertEq(address(0x0), address(0x1), "msg");
    }
    function testAssertEqBytes32() public {
        assertEq(bytes32("hi"), bytes32("hi"), "msg");
        assertEq(bytes32("hi"), bytes32("hi"));
    }
    function testFailAssertEqBytes32() public {
        assertEq(bytes32("hi"), bytes32("ho"));
    }
    function testFailAssertEqBytes32WithMsg() public {
        assertEq(bytes32("hi"), bytes32("ho"), "msg");
    }
    function testAssertEqInt() public {
        assertEq(-1, -1, "msg");
        assertEq(-1, -1);
    }
    function testFailAssertEqInt() public {
        assertEq(-1, -2);
    }
    function testFailAssertEqIntWithMsg() public {
        assertEq(-1, -2, "msg");
    }
    function testAssertEqUInt() public {
        assertEq(uint(1), uint(1), "msg");
        assertEq(uint(1), uint(1));
    }
    function testFailAssertEqUInt() public {
        assertEq(uint(1), uint(2));
    }
    function testFailAssertEqUIntWithMsg() public {
        assertEq(uint(1), uint(2), "msg");
    }
    function testAssertEqDecimalInt() public {
        assertEqDecimal(-1, -1, 18, "msg");
        assertEqDecimal(-1, -1, 18);
    }
    function testFailAssertEqDecimalInt() public {
        assertEqDecimal(-1, -2, 18);
    }
    function testFailAssertEqDecimalIntWithMsg() public {
        assertEqDecimal(-1, -2, 18, "msg");
    }
    function testAssertEqDecimalUInt() public {
        assertEqDecimal(uint(1), uint(1), 18, "msg");
        assertEqDecimal(uint(1), uint(1), 18);
    }
    function testFailAssertEqDecimalUInt() public {
        assertEqDecimal(uint(1), uint(2), 18);
    }
    function testFailAssertEqDecimalUIntWithMsg() public {
        assertEqDecimal(uint(1), uint(2), 18, "msg");
    }
    function testAssertNotEqAddr() public {
        assertNotEq(address(0x0), address(0x1), "msg");
        assertNotEq(address(0x0), address(0x1));
    }
    function testFailAssertNotEqAddr() public {
        assertNotEq(address(0x0), address(0x0));
    }
    function testFailAssertNotEqAddrWithMsg() public {
        assertNotEq(address(0x0), address(0x0), "msg");
    }
    function testAssertNotEqBytes32() public {
        assertNotEq(bytes32("hi"), bytes32("ho"), "msg");
        assertNotEq(bytes32("hi"), bytes32("ho"));
    }
    function testFailAssertNotEqBytes32() public {
        assertNotEq(bytes32("hi"), bytes32("hi"));
    }
    function testFailAssertNotEqBytes32WithMsg() public {
        assertNotEq(bytes32("hi"), bytes32("hi"), "msg");
    }
    function testAssertNotEqInt() public {
        assertNotEq(-1, -2, "msg");
        assertNotEq(-1, -2);
    }
    function testFailAssertNotEqInt() public {
        assertNotEq(-1, -1);
    }
    function testFailAssertNotEqIntWithMsg() public {
        assertNotEq(-1, -1, "msg");
    }
    function testAssertNotEqUInt() public {
        assertNotEq(uint(1), uint(2), "msg");
        assertNotEq(uint(1), uint(2));
    }
    function testFailAssertNotEqUInt() public {
        assertNotEq(uint(1), uint(1));
    }
    function testFailAssertNotEqUIntWithMsg() public {
        assertNotEq(uint(1), uint(1), "msg");
    }
    function testAssertNotEqDecimalInt() public {
        assertNotEqDecimal(-1, -2, 18, "msg");
        assertNotEqDecimal(-1, -2, 18);
    }
    function testFailAssertNotEqDecimalInt() public {
        assertNotEqDecimal(-1, -1, 18);
    }
    function testFailAssertNotEqDecimalIntWithMsg() public {
        assertNotEqDecimal(-1, -1, 18, "msg");
    }
    function testAssertNotEqDecimalUInt() public {
        assertNotEqDecimal(uint(1), uint(2), 18, "msg");
        assertNotEqDecimal(uint(1), uint(2), 18);
    }
    function testFailAssertNotEqDecimalUInt() public {
        assertNotEqDecimal(uint(1), uint(1), 18);
    }
    function testFailAssertNotEqDecimalUIntWithMsg() public {
        assertNotEqDecimal(uint(1), uint(1), 18, "msg");
    }
    function testAssertGtUInt() public {
        assertGt(uint(2), uint(1), "msg");
        assertGt(uint(3), uint(2));
    }
    function testFailAssertGtUInt() public {
        assertGt(uint(1), uint(2));
    }
    function testFailAssertGtUIntWithMsg() public {
        assertGt(uint(1), uint(2), "msg");
    }
    function testAssertGtInt() public {
        assertGt(-1, -2, "msg");
        assertGt(-1, -3);
    }
    function testFailAssertGtInt() public {
        assertGt(-2, -1);
    }
    function testFailAssertGtIntWithMsg() public {
        assertGt(-2, -1, "msg");
    }
    function testAssertGtDecimalUInt() public {
        assertGtDecimal(uint(2), uint(1), 18, "msg");
        assertGtDecimal(uint(3), uint(2), 18);
    }
    function testFailAssertGtDecimalUInt() public {
        assertGtDecimal(uint(1), uint(2), 18);
    }
    function testFailAssertGtDecimalUIntWithMsg() public {
        assertGtDecimal(uint(1), uint(2), 18, "msg");
    }
    function testAssertGtDecimalInt() public {
        assertGtDecimal(-1, -2, 18, "msg");
        assertGtDecimal(-1, -3, 18);
    }
    function testFailAssertGtDecimalInt() public {
        assertGtDecimal(-2, -1, 18);
    }
    function testFailAssertGtDecimalIntWithMsg() public {
        assertGtDecimal(-2, -1, 18, "msg");
    }
    function testAssertGeUInt() public {
        assertGe(uint(2), uint(1), "msg");
        assertGe(uint(2), uint(2));
    }
    function testFailAssertGeUInt() public {
        assertGe(uint(1), uint(2));
    }
    function testFailAssertGeUIntWithMsg() public {
        assertGe(uint(1), uint(2), "msg");
    }
    function testAssertGeInt() public {
        assertGe(-1, -2, "msg");
        assertGe(-1, -1);
    }
    function testFailAssertGeInt() public {
        assertGe(-2, -1);
    }
    function testFailAssertGeIntWithMsg() public {
        assertGe(-2, -1, "msg");
    }
    function testAssertGeDecimalUInt() public {
        assertGeDecimal(uint(2), uint(1), 18, "msg");
        assertGeDecimal(uint(2), uint(2), 18);
    }
    function testFailAssertGeDecimalUInt() public {
        assertGeDecimal(uint(1), uint(2), 18);
    }
    function testFailAssertGeDecimalUIntWithMsg() public {
        assertGeDecimal(uint(1), uint(2), 18, "msg");
    }
    function testAssertGeDecimalInt() public {
        assertGeDecimal(-1, -2, 18, "msg");
        assertGeDecimal(-1, -2, 18);
    }
    function testFailAssertGeDecimalInt() public {
        assertGeDecimal(-2, -1, 18);
    }
    function testFailAssertGeDecimalIntWithMsg() public {
        assertGeDecimal(-2, -1, 18, "msg");
    }
    function testAssertLtUInt() public {
        assertLt(uint(1), uint(2), "msg");
        assertLt(uint(1), uint(3));
    }
    function testFailAssertLtUInt() public {
        assertLt(uint(2), uint(2));
    }
    function testFailAssertLtUIntWithMsg() public {
        assertLt(uint(3), uint(2), "msg");
    }
    function testAssertLtInt() public {
        assertLt(-2, -1, "msg");
        assertLt(-1, 0);
    }
    function testFailAssertLtInt() public {
        assertLt(-1, -2);
    }
    function testFailAssertLtIntWithMsg() public {
        assertLt(-1, -1, "msg");
    }
    function testAssertLtDecimalUInt() public {
        assertLtDecimal(uint(1), uint(2), 18, "msg");
        assertLtDecimal(uint(2), uint(3), 18);
    }
    function testFailAssertLtDecimalUInt() public {
        assertLtDecimal(uint(1), uint(1), 18);
    }
    function testFailAssertLtDecimalUIntWithMsg() public {
        assertLtDecimal(uint(2), uint(1), 18, "msg");
    }
    function testAssertLtDecimalInt() public {
        assertLtDecimal(-2, -1, 18, "msg");
        assertLtDecimal(-2, -1, 18);
    }
    function testFailAssertLtDecimalInt() public {
        assertLtDecimal(-2, -2, 18);
    }
    function testFailAssertLtDecimalIntWithMsg() public {
        assertLtDecimal(-1, -2, 18, "msg");
    }
    function testAssertLeUInt() public {
        assertLe(uint(1), uint(2), "msg");
        assertLe(uint(1), uint(1));
    }
    function testFailAssertLeUInt() public {
        assertLe(uint(4), uint(2));
    }
    function testFailAssertLeUIntWithMsg() public {
        assertLe(uint(3), uint(2), "msg");
    }
    function testAssertLeInt() public {
        assertLe(-2, -1, "msg");
        assertLe(-1, -1);
    }
    function testFailAssertLeInt() public {
        assertLe(-1, -2);
    }
    function testFailAssertLeIntWithMsg() public {
        assertLe(-1, -3, "msg");
    }
    function testAssertLeDecimalUInt() public {
        assertLeDecimal(uint(1), uint(2), 18, "msg");
        assertLeDecimal(uint(2), uint(2), 18);
    }
    function testFailAssertLeDecimalUInt() public {
        assertLeDecimal(uint(1), uint(0), 18);
    }
    function testFailAssertLeDecimalUIntWithMsg() public {
        assertLeDecimal(uint(1), uint(0), 18, "msg");
    }
    function testAssertLeDecimalInt() public {
        assertLeDecimal(-2, -1, 18, "msg");
        assertLeDecimal(-2, -2, 18);
    }
    function testFailAssertLeDecimalInt() public {
        assertLeDecimal(-2, -3, 18);
    }
    function testFailAssertLeDecimalIntWithMsg() public {
        assertLeDecimal(-1, -2, 18, "msg");
    }
    function testAssertNotEqString() public {
        assertNotEq(new string(1), new string(2), "msg");
        assertNotEq(new string(1), new string(2));
    }
    function testFailAssertNotEqString() public {
        assertNotEq(new string(1), new string(1));
    }
    function testFailAssertNotEqStringWithMsg() public {
        assertNotEq(new string(1), new string(1), "msg");
    }
    function testAssertNotEq0Bytes() public {
        assertNotEq0(bytes("hi"), bytes("ho"), "msg");
        assertNotEq0(bytes("hi"), bytes("ho"));
    }
    function testFailAssertNotEq0Bytes() public {
        assertNotEq0(bytes("hi"), bytes("hi"));
    }
    function testFailAssertNotEq0BytesWithMsg() public {
        assertNotEq0(bytes("hi"), bytes("hi"), "msg");
    }
    function fail() internal override {
        super.fail();
    }
}