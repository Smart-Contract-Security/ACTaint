pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { DateTime } from "../external/DateTime.sol";
contract DateTimeTest is Test {
    function testFormatFirstAndJan() public {
        uint256 timestamp = 1640995200; 
        assertEq(DateTime.format(timestamp), "1st Jan 2022");
    }
    function testFormatSecondAndFeb() public {
        uint256 timestamp = 1643760000; 
        assertEq(DateTime.format(timestamp), "2nd Feb 2022");
    }
    function testFormatThirdAndMar() public {
        uint256 timestamp = 1646265600; 
        assertEq(DateTime.format(timestamp), "3rd Mar 2022");
    }
    function testFormatFourthAndApr() public {
        uint256 timestamp = 1649030400; 
        assertEq(DateTime.format(timestamp), "4th Apr 2022");
    }
    function testFormatEleventhAndMay() public {
        uint256 timestamp = 1652227200; 
        assertEq(DateTime.format(timestamp), "11th May 2022");
    }
    function testFormatTwelfthAndJune() public {
        uint256 timestamp = 1654992000; 
        assertEq(DateTime.format(timestamp), "12th June 2022");
    }
    function testFormatTwentiethAndJuly() public {
        uint256 timestamp = 1658275200; 
        assertEq(DateTime.format(timestamp), "20th July 2022");
    }
    function testFormatTwentyFirstAndAug() public {
        uint256 timestamp = 1661040000; 
        assertEq(DateTime.format(timestamp), "21st Aug 2022");
    }
    function testFormatTwentySecondAndSept() public {
        uint256 timestamp = 1663804800; 
        assertEq(DateTime.format(timestamp), "22nd Sept 2022");
    }
    function testFormatTwentyThirdAndOct() public {
        uint256 timestamp = 1666483200; 
        assertEq(DateTime.format(timestamp), "23rd Oct 2022");
    }
    function testFormatThirthAndNov() public {
        uint256 timestamp = 1669766400; 
        assertEq(DateTime.format(timestamp), "30th Nov 2022");
    }
    function testFormatThirtyFirstAndDec() public {
        uint256 timestamp = 1672444800; 
        assertEq(DateTime.format(timestamp), "31st Dec 2022");
    }
    function testFormatThirteenthAndJan() public {
        uint256 timestamp = 1642032000; 
        assertEq(DateTime.format(timestamp), "13th Jan 2022");
    }
}