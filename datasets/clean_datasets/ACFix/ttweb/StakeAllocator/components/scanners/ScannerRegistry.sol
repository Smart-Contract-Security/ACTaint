pragma solidity ^0.8.9;
import "../BaseComponentUpgradeable.sol";
import "./ScannerRegistryCore.sol";
import "./ScannerRegistryManaged.sol";
import "./ScannerRegistryEnable.sol";
import "./ScannerRegistryMetadata.sol";
contract ScannerRegistry is BaseComponentUpgradeable, ScannerRegistryCore, ScannerRegistryManaged, ScannerRegistryEnable, ScannerRegistryMetadata {
    event DeregisteredScanner(uint256 scannerId);
    event ConfiguredMigration(uint256 sunsettingTime, address scannerPoolRegistry);
    string public constant version = "0.1.4";
    mapping(uint256 => bool) public optingOutOfMigration;
    uint256 public sunsettingTime;
    ScannerPoolRegistry public scannerPoolRegistry;
    constructor(address forwarder) initializer ForwardedContext(forwarder) {}
    error CannotDeregister(uint256 scannerId);
    function initialize(
        address __manager,
        string calldata __name,
        string calldata __symbol
    ) public initializer {
        __BaseComponentUpgradeable_init(__manager);
        __ERC721_init(__name, __symbol);
    }
    function getScannerState(uint256 scannerId)
        external
        view
        returns (
            bool registered,
            address owner,
            uint256 chainId,
            string memory metadata,
            bool enabled,
            uint256 disabledFlags
        )
    {
        if (scannerPoolRegistry.isScannerRegistered(address(uint160(scannerId)))) {
            return _getScannerStateFromScannerPool(scannerId);
        } else {
            return _getScannerState(scannerId);
        }
    }
    function _getScannerStateFromScannerPool(uint256 scannerId)
        private
        view
        returns (
            bool registered,
            address owner,
            uint256 chainId,
            string memory metadata,
            bool enabled,
            uint256 disabledFlags
        )
    {
        bool disabled;
        (registered, owner, chainId, metadata, enabled, disabled) = scannerPoolRegistry.getScannerState(address(uint160(scannerId)));
        if (disabled) {
            disabledFlags = 1;
        }
        return (registered, owner, chainId, metadata, enabled, disabledFlags);
    }
    function _getScannerState(uint256 scannerId)
        private
        view
        returns (
            bool registered,
            address owner,
            uint256 chainId,
            string memory metadata,
            bool enabled,
            uint256 disabledFlags
        )
    {
        (registered, owner, chainId, metadata) = super.getScanner(scannerId);
        return (registered, owner, chainId, metadata, isEnabled(scannerId), _getDisableFlags(scannerId));
    }
    function _getScannerFromScannerPool(uint256 scannerId)
        private
        view
        returns (
            bool registered,
            address owner,
            uint256 chainId,
            string memory metadata
        )
    {
        (registered, owner, chainId, metadata, , ) = scannerPoolRegistry.getScannerState(address(uint160(scannerId)));
        return (registered, owner, chainId, metadata);
    }
    function getScanner(uint256 scannerId)
        public
        view
        virtual
        override
        returns (
            bool registered,
            address owner,
            uint256 chainId,
            string memory metadata
        )
    {
        if (scannerPoolRegistry.isScannerRegistered(address(uint160(scannerId)))) {
            return _getScannerFromScannerPool(scannerId);
        } else {
            return super.getScanner(scannerId);
        }
    }
    function isEnabled(uint256 scannerId) public view virtual override returns (bool) {
        if (hasMigrationEnded()) {
            return false;
        } else if (scannerPoolRegistry.isScannerRegistered(address(uint160(scannerId)))) {
            return scannerPoolRegistry.isScannerOperational(address(uint160(scannerId)));
        } else {
            return super.isEnabled(scannerId);
        }
    }
    function hasMigrationEnded() public view returns (bool) {
        return sunsettingTime < block.timestamp;
    }
    function deregisterScannerNode(uint256 scannerId) external onlyRole(SCANNER_2_SCANNER_POOL_MIGRATOR_ROLE) {
        if (optingOutOfMigration[scannerId]) revert CannotDeregister(scannerId);
        _burn(scannerId);
        delete _disabled[scannerId];
        delete _managers[scannerId];
        delete _scannerMetadata[scannerId];
        emit DeregisteredScanner(scannerId);
    }
    function setMigrationPrefrence(uint256 scannerId, bool isOut) external onlyOwnerOf(scannerId) {
        optingOutOfMigration[scannerId] = isOut;
    }
    function configureMigration(uint256 _sunsettingTime, address _scannerPoolRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_sunsettingTime == 0) revert ZeroAmount("_sunsettingTime");
        if (_scannerPoolRegistry == address(0)) revert ZeroAddress("_scannerPoolRegistry");
        sunsettingTime = _sunsettingTime;
        scannerPoolRegistry = ScannerPoolRegistry(_scannerPoolRegistry);
        emit ConfiguredMigration(sunsettingTime, _scannerPoolRegistry);
    }
    function _getStakeThreshold(uint256 subject)
        internal
        view
        virtual
        override(ScannerRegistryCore, ScannerRegistryMetadata)
        returns (StakeThreshold memory)
    {
        return super._getStakeThreshold(subject);
    }
    function _msgSender()
        internal
        view
        virtual
        override(BaseComponentUpgradeable, ScannerRegistryCore, ScannerRegistryEnable)
        returns (address sender)
    {
        return super._msgSender();
    }
    function _msgData()
        internal
        view
        virtual
        override(BaseComponentUpgradeable, ScannerRegistryCore, ScannerRegistryEnable)
        returns (bytes calldata)
    {
        return super._msgData();
    }
    uint256[47] private __gap;
}