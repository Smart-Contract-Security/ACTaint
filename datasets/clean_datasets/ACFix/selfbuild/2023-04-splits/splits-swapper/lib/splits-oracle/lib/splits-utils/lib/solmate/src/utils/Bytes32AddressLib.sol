pragma solidity >=0.8.0;
library Bytes32AddressLib {
    function fromLast20Bytes(bytes32 bytesValue) internal pure returns (address) {
        return address(uint160(uint256(bytesValue)));
    }
    function fillLast12Bytes(address addressValue) internal pure returns (bytes32) {
        return bytes32(bytes20(addressValue));
    }
}