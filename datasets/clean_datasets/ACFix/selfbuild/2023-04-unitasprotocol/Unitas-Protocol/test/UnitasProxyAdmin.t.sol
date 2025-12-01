pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/UnitasProxyAdmin.sol";
contract UnitasProxyAdminTest is Test {
    address internal immutable _admin = vm.addr(0x1);
    function test_constructor_OwnerChanged() public {
        UnitasProxyAdmin proxyAdmin = new UnitasProxyAdmin(_admin);
        assertEq(proxyAdmin.owner(), _admin, "new owner");
    }
}