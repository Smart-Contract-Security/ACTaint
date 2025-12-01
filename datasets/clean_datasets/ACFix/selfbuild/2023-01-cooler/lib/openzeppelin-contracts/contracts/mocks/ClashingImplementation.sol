pragma solidity ^0.8.0;
contract ClashingImplementation {
    function admin() external pure returns (address) {
        return 0x0000000000000000000000000000000011111142;
    }
    function delegatedFunction() external pure returns (bool) {
        return true;
    }
}