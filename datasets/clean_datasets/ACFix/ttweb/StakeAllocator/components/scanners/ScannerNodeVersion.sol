pragma solidity ^0.8.9;
import "../BaseComponentUpgradeable.sol";
contract ScannerNodeVersion is BaseComponentUpgradeable {
    string public scannerNodeVersion;
    string public scannerNodeBetaVersion;
    string public constant version = "0.1.1";
    event ScannerNodeVersionUpdated(string newVersion, string oldVersion);
    event ScannerNodeBetaVersionUpdated(string newVersion, string oldVersion);
    error SameScannerNodeVersion();
    constructor(address forwarder) initializer ForwardedContext(forwarder) {}
    function initialize(address __manager) public initializer {
        __BaseComponentUpgradeable_init(__manager);
    }
    function setScannerNodeVersion(string calldata _version) public onlyRole(SCANNER_VERSION_ROLE) {
        if (keccak256(abi.encodePacked(scannerNodeVersion)) == keccak256(abi.encodePacked(_version))) revert SameScannerNodeVersion();
        emit ScannerNodeVersionUpdated(_version, scannerNodeVersion);
        scannerNodeVersion = _version;
    }
    function setScannerNodeBetaVersion(string calldata _version) public onlyRole(SCANNER_BETA_VERSION_ROLE) {
        if (keccak256(abi.encodePacked(scannerNodeBetaVersion)) == keccak256(abi.encodePacked(_version))) revert SameScannerNodeVersion();
        emit ScannerNodeBetaVersionUpdated(_version, scannerNodeBetaVersion);
        scannerNodeBetaVersion = _version;
    }
    uint256[48] private __gap;
}