pragma solidity ^0.7.0;
interface IDistributorCallback {
    function distributorCallback(bytes calldata callbackData) external;
}