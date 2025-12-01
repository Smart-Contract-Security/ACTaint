pragma solidity ^0.8.0;
contract MockEmergencyOracle {
    function getMarkPrice(
    ) external view returns (uint256 price){
        return 1000000;
    }
}