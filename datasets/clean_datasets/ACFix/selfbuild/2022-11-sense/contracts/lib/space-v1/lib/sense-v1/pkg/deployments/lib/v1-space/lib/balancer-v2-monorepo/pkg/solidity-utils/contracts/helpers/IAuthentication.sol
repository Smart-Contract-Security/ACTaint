pragma solidity ^0.7.0;
interface IAuthentication {
    function getActionId(bytes4 selector) external view returns (bytes32);
}