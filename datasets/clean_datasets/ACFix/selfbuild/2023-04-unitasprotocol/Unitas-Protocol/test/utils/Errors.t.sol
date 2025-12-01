pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../../src/utils/Errors.sol";
contract ErrorsTest is Test {
    function test_require_WhenTrue() public pure {
        _require(true, Errors.ADDRESS_ZERO);
        _require(true, Errors.TOKEN_TYPE_INVALID);
        _require(true, Errors.SWAP_RESULT_INVALID);
    }
    function test_require_FailWhenFalse() public {
        vm.expectRevert("Unitas: 1000");
        _require(false, Errors.ADDRESS_ZERO);
         vm.expectRevert("Unitas: 2000");
        _require(false, Errors.TOKEN_TYPE_INVALID);
         vm.expectRevert("Unitas: 2100");
        _require(false, Errors.SWAP_RESULT_INVALID);
    }
    function test_revert_Fail() public {
        vm.expectRevert("Unitas: 1000");
        _revert(Errors.ADDRESS_ZERO);
    }
}