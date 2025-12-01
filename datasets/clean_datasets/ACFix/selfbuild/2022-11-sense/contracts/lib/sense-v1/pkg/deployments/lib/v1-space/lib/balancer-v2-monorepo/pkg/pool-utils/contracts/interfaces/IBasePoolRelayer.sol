pragma solidity ^0.7.0;
interface IBasePoolRelayer {
    function hasCalledPool(bytes32 poolId) external view returns (bool);
}