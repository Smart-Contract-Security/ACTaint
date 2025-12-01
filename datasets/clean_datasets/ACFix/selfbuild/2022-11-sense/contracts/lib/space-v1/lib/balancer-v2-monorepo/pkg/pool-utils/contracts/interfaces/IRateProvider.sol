pragma solidity ^0.7.0;
interface IRateProvider {
    function getRate() external view returns (uint256);
}