pragma solidity ^0.7.0;
import "./IBasePoolRelayer.sol";
interface IRelayedBasePool {
    function getRelayer() external view returns (IBasePoolRelayer);
}