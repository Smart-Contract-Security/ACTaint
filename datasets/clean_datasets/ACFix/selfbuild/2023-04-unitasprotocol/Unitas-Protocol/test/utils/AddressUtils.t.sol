pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../../src/utils/AddressUtils.sol";
import "../../src/utils/Errors.sol";
import "./Functions.sol";
contract AddressUtilsTest is Test {
    function test_checkNotZero_FailWhenZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        AddressUtils.checkNotZero(address(0));
    }
    function test_checkNotZero_Valid() public pure {
        AddressUtils.checkNotZero(vm.addr(0x1));
    }
    function test_checkContract_FailWhenCodeSizeZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_CODE_SIZE_ZERO));
        AddressUtils.checkContract(vm.addr(0x1));
    }
    function test_checkContract_Valid() public view {
        AddressUtils.checkContract(address(this));
    }
}