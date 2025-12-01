pragma solidity ^0.8.17;
interface IController {
    function canCall(
        address target,
        bool useEth,
        bytes calldata data
    ) external view returns (bool, address[] memory, address[] memory);
}