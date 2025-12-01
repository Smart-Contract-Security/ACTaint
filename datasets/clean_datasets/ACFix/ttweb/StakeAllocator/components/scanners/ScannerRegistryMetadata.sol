pragma solidity ^0.8.9;
import "./ScannerRegistryCore.sol";
abstract contract ScannerRegistryMetadata is ScannerRegistryCore {
    struct ScannerMetadata {
        uint256 chainId;
        string metadata;
    }
    mapping(uint256 => ScannerMetadata) internal _scannerMetadata;
    function getScanner(uint256 scannerId) public virtual view returns (bool registered, address owner, uint256 chainId, string memory metadata) {
        bool exists = _exists(scannerId);
        return (
            exists,
            exists ? ownerOf(scannerId) : address(0),
            _scannerMetadata[scannerId].chainId,
            _scannerMetadata[scannerId].metadata
        );
    }
    function getScannerChainId(uint256 scannerId) public view returns (uint256) {
        return _scannerMetadata[scannerId].chainId;
    }
    function _getStakeThreshold(uint256 subject) override virtual internal view returns(StakeThreshold memory) {
        return _stakeThresholds[getScannerChainId(subject)];
    }
    uint256[49] private __gap;
}