pragma solidity >=0.5.0;
interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}