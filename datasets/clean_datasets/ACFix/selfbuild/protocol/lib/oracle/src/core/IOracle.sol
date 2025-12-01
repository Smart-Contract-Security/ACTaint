pragma solidity ^0.8.17;
interface IOracle {
    function getPrice(address token) external view returns (uint);
}