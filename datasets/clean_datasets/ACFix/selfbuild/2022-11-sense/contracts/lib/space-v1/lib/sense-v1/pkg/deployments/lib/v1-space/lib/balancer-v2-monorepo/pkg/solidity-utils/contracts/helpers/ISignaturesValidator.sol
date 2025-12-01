pragma solidity ^0.7.0;
interface ISignaturesValidator {
    function getDomainSeparator() external view returns (bytes32);
    function getNextNonce(address user) external view returns (uint256);
}