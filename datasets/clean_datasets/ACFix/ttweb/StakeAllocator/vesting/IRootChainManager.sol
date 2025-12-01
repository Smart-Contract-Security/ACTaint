pragma solidity ^0.8.9;
interface IRootChainManager {
    function tokenToType(address) external view returns (bytes32);
    function typeToPredicate(bytes32) external view returns (address);
    function depositFor(address, address, bytes calldata) external;
    function exit(bytes calldata) external;
}