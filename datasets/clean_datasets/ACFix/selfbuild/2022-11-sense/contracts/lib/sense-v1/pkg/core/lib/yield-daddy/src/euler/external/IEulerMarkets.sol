pragma solidity ^0.8.13;
interface IEulerMarkets {
    function underlyingToEToken(address underlying) external view returns (address);
}