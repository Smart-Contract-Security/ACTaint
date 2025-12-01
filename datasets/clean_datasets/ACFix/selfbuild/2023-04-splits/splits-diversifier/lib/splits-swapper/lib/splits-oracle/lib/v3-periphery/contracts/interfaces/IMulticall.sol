pragma solidity >=0.7.5;
pragma abicoder v2;
interface IMulticall {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}