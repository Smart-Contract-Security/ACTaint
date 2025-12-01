pragma solidity ^0.8.9;
import "../BaseComponentUpgradeable.sol";
import "./ScannerPoolRegistryCore.sol";
import "./ScannerPoolRegistryManaged.sol";
contract ScannerPoolRegistry is BaseComponentUpgradeable, ScannerPoolRegistryCore, ScannerPoolRegistryManaged {
    string public constant version = "0.1.0";
    constructor(address forwarder, address stakeAllocator) initializer ForwardedContext(forwarder) ScannerPoolRegistryCore(stakeAllocator) {}
    function initialize(
        address __manager,
        string calldata __name,
        string calldata __symbol,
        address __stakeSubjectGateway,
        uint256 __registrationDelay
    ) public initializer {
        __BaseComponentUpgradeable_init(__manager);
        __ScannerPoolRegistryCore_init(__name, __symbol, __stakeSubjectGateway, __registrationDelay);
    }
    function registerMigratedScannerPool(address scannerPoolAddress, uint256 chainId) external onlyRole(SCANNER_2_SCANNER_POOL_MIGRATOR_ROLE) returns (uint256 scannerPoolId) {
        return _registerScannerPool(scannerPoolAddress, chainId);
    }
    function registerMigratedScannerNode(ScannerNodeRegistration calldata req, bool disabled) external onlyRole(SCANNER_2_SCANNER_POOL_MIGRATOR_ROLE) {
        _registerScannerNode(req);
        if (disabled) {
            _setScannerDisableFlag(req.scanner, true);
        }
    }
    function _canSetEnableState(address scanner) internal view virtual override(ScannerPoolRegistryCore, ScannerPoolRegistryManaged) returns (bool) {
        return super._canSetEnableState(scanner) || hasRole(SCANNER_2_SCANNER_POOL_MIGRATOR_ROLE, _msgSender());
    }
    function _msgSender() internal view virtual override(BaseComponentUpgradeable, ScannerPoolRegistryCore) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(BaseComponentUpgradeable, ScannerPoolRegistryCore) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[50] private __gap;
}