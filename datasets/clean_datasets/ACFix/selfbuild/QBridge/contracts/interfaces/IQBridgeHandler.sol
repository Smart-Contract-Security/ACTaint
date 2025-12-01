pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
interface IQBridgeHandler {
    function setResource(bytes32 resourceID, address contractAddress) external;
    function setBurnable(address contractAddress) external;
    function deposit(bytes32 resourceID, address depositer, bytes calldata data) external;
    function depositETH(bytes32 resourceID, address depositer, bytes calldata data) external payable;
    function executeProposal(bytes32 resourceID, bytes calldata data) external;
    function withdraw(address tokenAddress, address recipient, uint amount) external;
}