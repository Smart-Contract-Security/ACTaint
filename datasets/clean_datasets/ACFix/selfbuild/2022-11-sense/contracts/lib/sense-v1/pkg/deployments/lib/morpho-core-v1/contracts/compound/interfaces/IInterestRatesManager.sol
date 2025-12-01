pragma solidity ^0.8.0;
interface IInterestRatesManager {
    function updateP2PIndexes(address _marketAddress) external;
}