pragma solidity >=0.4.21 <0.9.0;
interface IArbSys {
    function arbOSVersion() external pure returns (uint256);
    function arbChainID() external view returns (uint256);
    function arbBlockNumber() external view returns (uint256);
    function withdrawEth(address destination) external payable returns (uint256);
    function sendTxToL1(address destination, bytes calldata calldataForL1) external payable returns (uint256);
    function getTransactionCount(address account) external view returns (uint256);
    function getStorageAt(address account, uint256 index) external view returns (uint256);
    function isTopLevelCall() external view returns (bool);
    function wasMyCallersAddressAliased() external view returns (bool);
    function myCallersAddressWithoutAliasing() external view returns (address);
    function mapL1SenderContractAddressToL2Alias(address sender, address dest) external pure returns (address);
    function getStorageGasAvailable() external view returns (uint256);
    event L2ToL1Transaction(
        address caller,
        address indexed destination,
        uint256 indexed uniqueId,
        uint256 indexed batchNumber,
        uint256 indexInBatch,
        uint256 arbBlockNum,
        uint256 ethBlockNum,
        uint256 timestamp,
        uint256 callvalue,
        bytes data
    );
}