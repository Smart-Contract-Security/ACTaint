pragma solidity ^0.8.0;
interface IBeaconUpgradeable {
    function implementation() external view returns (address);
}