pragma solidity ^0.8.11;
interface IExecutor {
  struct ExecutorArgs {
    bytes32 transferId;
    uint256 amount;
    address to;
    address recovery;
    address assetId;
    bytes properties;
    bytes callData;
  }
  function originSender() external returns (address);
  function origin() external returns (uint32);
  function execute(ExecutorArgs calldata _args)
    external
    payable
    returns (bool success, bytes memory returnData);
}