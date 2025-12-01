pragma solidity ^0.8.9;
import "../BaseComponentUpgradeable.sol";
import "../staking/allocation/IStakeAllocator.sol";
import "../staking/stake_subjects/DelegatedStakeSubject.sol";
import "../../errors/GeneralErrors.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
abstract contract ScannerPoolRegistryCore is BaseComponentUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable, DelegatedStakeSubjectUpgradeable, EIP712Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    struct ScannerNode {
        bool registered;
        bool disabled;
        uint256 scannerPoolId;
        uint256 chainId;
        string metadata;
    }
    struct ScannerNodeRegistration {
        address scanner;
        uint256 scannerPoolId;
        uint256 chainId;
        string metadata;
        uint256 timestamp;
    }
    bytes32 private constant _SCANNERNODEREGISTRATION_TYPEHASH =
        keccak256("ScannerNodeRegistration(address scanner,uint256 scannerPoolId,uint256 chainId,string metadata,uint256 timestamp)");
    IStakeAllocator private immutable _stakeAllocator;
    CountersUpgradeable.Counter private _scannerPoolIdCounter;
    mapping(address => ScannerNode) internal _scannerNodes;
    mapping(uint256 => EnumerableSet.AddressSet) private _scannerNodeOwnership;
    mapping(uint256 => uint256) private _enabledScanners;
    mapping(uint256 => StakeThreshold) private _scannerStakeThresholds;
    mapping(uint256 => uint256) private _scannerPoolChainId;
    uint256 public registrationDelay;
    event ScannerUpdated(uint256 indexed scannerId, uint256 indexed chainId, string metadata, uint256 scannerPool);
    event ManagedStakeThresholdChanged(uint256 indexed chainId, uint256 min, uint256 max, bool activated);
    event RegistrationDelaySet(uint256 delay);
    event ScannerEnabled(uint256 indexed scannerId, bool indexed enabled, address sender, bool disableFlag);
    event EnabledScannersChanged(uint256 indexed scannerPoolId, uint256 enabledScanners);
    event ScannerPoolRegistered(uint256 indexed scannerPoolId, uint256 indexed chainId);
    error ScannerPoolNotRegistered(uint256 scannerPoolId);
    error ScannerExists(address scanner);
    error ScannerNotRegistered(address scanner);
    error PublicRegistrationDisabled(uint256 chainId);
    error RegisteringTooLate();
    error SignatureDoesNotMatch();
    error CannotSetScannerActivation();
    error SenderNotScannerPool(address sender, uint256 scannerPoolId);
    error ChainIdMismatch(uint256 expected, uint256 provided);
    error ActionShutsDownPool();
    modifier onlyScannerPool(uint256 scannerPoolId) {
        if (_msgSender() != ownerOf(scannerPoolId)) revert SenderNotScannerPool(_msgSender(), scannerPoolId);
        _;
    }
    modifier onlyRegisteredScanner(address scanner) {
        if (!isScannerRegistered(scanner)) revert ScannerNotRegistered(scanner);
        _;
    }
    constructor(address __stakeAllocator) {
        if (__stakeAllocator == address(0)) revert ZeroAddress("__stakeAllocator");
        _stakeAllocator = IStakeAllocator(__stakeAllocator);
    }
    function __ScannerPoolRegistryCore_init(
        string calldata __name,
        string calldata __symbol,
        address __stakeSubjectGateway,
        uint256 __registrationDelay
    ) internal initializer {
        __ERC721_init(__name, __symbol);
        __ERC721Enumerable_init();
        __EIP712_init("ScannerPoolRegistry", "1");
        __StakeSubjectUpgradeable_init(__stakeSubjectGateway);
        _setRegistrationDelay(__registrationDelay);
    }
    function isRegistered(uint256 scannerPoolId) public view override returns (bool) {
        return _exists(scannerPoolId);
    }
    function registerScannerPool(uint256 chainId) external returns (uint256 scannerPoolId) {
        return _registerScannerPool(_msgSender(), chainId);
    }
    function _registerScannerPool(address scannerPoolAddress, uint256 chainId) internal returns (uint256 scannerPoolId) {
        if (scannerPoolAddress == address(0)) revert ZeroAddress("scannerPoolAddress");
        if (chainId == 0) revert ZeroAmount("chainId");
        _scannerPoolIdCounter.increment();
        scannerPoolId = _scannerPoolIdCounter.current();
        _safeMint(scannerPoolAddress, scannerPoolId);
        _scannerPoolChainId[scannerPoolId] = chainId;
        emit ScannerPoolRegistered(scannerPoolId, chainId);
        return scannerPoolId;
    }
    function monitoredChainId(uint256 scannerPoolId) public view returns (uint256) {
        return _scannerPoolChainId[scannerPoolId];
    }
    function isScannerRegistered(address scanner) public view returns (bool) {
        return _scannerNodes[scanner].registered;
    }
    function isScannerRegisteredTo(address scanner, uint256 scannerPoolId) public view returns (bool) {
        return _scannerNodeOwnership[scannerPoolId].contains(scanner);
    }
    function registerScannerNode(ScannerNodeRegistration calldata req, bytes calldata signature) external onlyScannerPool(req.scannerPoolId) {
        if (req.timestamp + registrationDelay < block.timestamp) revert RegisteringTooLate();
        if (
            !SignatureCheckerUpgradeable.isValidSignatureNow(
                req.scanner,
                _hashTypedDataV4(
                    keccak256(abi.encode(_SCANNERNODEREGISTRATION_TYPEHASH, req.scanner, req.scannerPoolId, req.chainId, keccak256(abi.encodePacked(req.metadata)), req.timestamp))
                ),
                signature
            )
        ) revert SignatureDoesNotMatch();
        _registerScannerNode(req);
        _allocationOnAddedEnabledScanner(req.scannerPoolId);
    }
    function _allocationOnAddedEnabledScanner(uint256 scannerPoolId) private {
        uint256 unallocatedStake = _stakeAllocator.unallocatedStakeFor(SCANNER_POOL_SUBJECT, scannerPoolId);
        uint256 allocatedStake = _stakeAllocator.allocatedStakeFor(SCANNER_POOL_SUBJECT, scannerPoolId);
        uint256 min = _scannerStakeThresholds[_scannerPoolChainId[scannerPoolId]].min;
        if (allocatedStake / _enabledScanners[scannerPoolId] >  min) {
            return;
        }
        if ((unallocatedStake + allocatedStake) / _enabledScanners[scannerPoolId] < min) {
            revert ActionShutsDownPool();
        }
        _stakeAllocator.allocateOwnStake(SCANNER_POOL_SUBJECT, scannerPoolId, unallocatedStake);
    }
    function _registerScannerNode(ScannerNodeRegistration calldata req) internal {
        if (isScannerRegistered(req.scanner)) revert ScannerExists(req.scanner);
        if (_scannerPoolChainId[req.scannerPoolId] != req.chainId)
            revert ChainIdMismatch(_scannerPoolChainId[req.scannerPoolId], req.chainId);
        _scannerNodes[req.scanner] = ScannerNode({ registered: true, disabled: false, scannerPoolId: req.scannerPoolId, chainId: req.chainId, metadata: req.metadata });
        !_scannerNodeOwnership[req.scannerPoolId].add(req.scanner);
        emit ScannerUpdated(scannerAddressToId(req.scanner), req.chainId, req.metadata, req.scannerPoolId);
        _addEnabledScanner(req.scannerPoolId);
    }
    function updateScannerMetadata(address scanner, string calldata metadata) external {
        if (!isScannerRegistered(scanner)) revert ScannerNotRegistered(scanner);
        if (_msgSender() != ownerOf(_scannerNodes[scanner].scannerPoolId)) {
            revert SenderNotScannerPool(_msgSender(), _scannerNodes[scanner].scannerPoolId);
        }
        _scannerNodes[scanner].metadata = metadata;
        emit ScannerUpdated(scannerAddressToId(scanner), _scannerNodes[scanner].chainId, metadata, _scannerNodes[scanner].scannerPoolId);
    }
    function totalScannersRegistered(uint256 scannerPoolId) public view returns (uint256) {
        return _scannerNodeOwnership[scannerPoolId].length();
    }
    function registeredScannerAtIndex(uint256 scannerPoolId, uint256 index) external view returns (ScannerNode memory) {
        return _scannerNodes[_scannerNodeOwnership[scannerPoolId].at(index)];
    }
    function registeredScannerAddressAtIndex(uint256 scannerPoolId, uint256 index) external view returns (address) {
        return _scannerNodeOwnership[scannerPoolId].at(index);
    }
    function scannerAddressToId(address scanner) public pure returns (uint256) {
        return uint256(uint160(scanner));
    }
    function scannerIdToAddress(uint256 scannerId) public pure returns (address) {
        return address(uint160(scannerId));
    }
    function isScannerDisabled(address scanner) public view returns (bool) {
        return _scannerNodes[scanner].disabled;
    }
    function isScannerOperational(address scanner) public view returns (bool) {
        ScannerNode storage node = _scannerNodes[scanner];
        StakeThreshold storage stake = _scannerStakeThresholds[node.chainId];
        return (node.registered && !node.disabled && (!stake.activated || _isScannerStakedOverMin(scanner)) && _exists(node.scannerPoolId));
    }
    function willNewScannerShutdownPool(uint256 scannerPoolId) public view returns (bool) {
        uint256 unallocatedStake = _stakeAllocator.unallocatedStakeFor(SCANNER_POOL_SUBJECT, scannerPoolId);
        uint256 allocatedStake = _stakeAllocator.allocatedStakeFor(SCANNER_POOL_SUBJECT, scannerPoolId);
        uint256 min = _scannerStakeThresholds[_scannerPoolChainId[scannerPoolId]].min;
        return (allocatedStake + unallocatedStake) / (_enabledScanners[scannerPoolId] + 1) < min;
    }
    function _isScannerStakedOverMin(address scanner) internal view returns (bool) {
        ScannerNode storage node = _scannerNodes[scanner];
        StakeThreshold storage stake = _scannerStakeThresholds[node.chainId];
        return _stakeAllocator.allocatedStakePerManaged(SCANNER_POOL_SUBJECT, node.scannerPoolId) >= stake.min;
    }
    function _canSetEnableState(address scanner) internal view virtual returns (bool) {
        return _msgSender() == scanner || ownerOf(_scannerNodes[scanner].scannerPoolId) == _msgSender();
    }
    function enableScanner(address scanner) public onlyRegisteredScanner(scanner) {
        if (!_canSetEnableState(scanner)) revert CannotSetScannerActivation();
        _addEnabledScanner(_scannerNodes[scanner].scannerPoolId);
        _allocationOnAddedEnabledScanner(_scannerNodes[scanner].scannerPoolId);
        _setScannerDisableFlag(scanner, false);
    }
    function disableScanner(address scanner) public onlyRegisteredScanner(scanner) {
        if (!_canSetEnableState(scanner)) revert CannotSetScannerActivation();
        _removeEnabledScanner(_scannerNodes[scanner].scannerPoolId);
        _setScannerDisableFlag(scanner, true);
    }
    function _setScannerDisableFlag(address scanner, bool value) internal {
        _scannerNodes[scanner].disabled = value;
        emit ScannerEnabled(scannerAddressToId(scanner), isScannerOperational(scanner), _msgSender(), value);
    }
    function _addEnabledScanner(uint256 scannerPoolId) private {
        _enabledScanners[scannerPoolId] += 1;
        emit EnabledScannersChanged(scannerPoolId, _enabledScanners[scannerPoolId]);
    }
    function _removeEnabledScanner(uint256 scannerPoolId) private {
        _enabledScanners[scannerPoolId] -= 1;
        emit EnabledScannersChanged(scannerPoolId, _enabledScanners[scannerPoolId]);
    }
    function getScanner(address scanner) public view returns (ScannerNode memory) {
        return _scannerNodes[scanner];
    }
    function getScannerState(address scanner)
        external
        view
        returns (
            bool registered,
            address owner,
            uint256 chainId,
            string memory metadata,
            bool operational,
            bool disabled
        )
    {
        ScannerNode memory scannerNode = getScanner(scanner);
        return (
            scannerNode.registered,
            scannerNode.registered ? ownerOf(scannerNode.scannerPoolId) : address(0),
            scannerNode.chainId,
            scannerNode.metadata,
            isScannerOperational(scanner),
            scannerNode.disabled
        );
    }
    function setManagedStakeThreshold(StakeThreshold calldata newStakeThreshold, uint256 chainId) external onlyRole(SCANNER_POOL_ADMIN_ROLE) {
        if (chainId == 0) revert ZeroAmount("chainId");
        if (newStakeThreshold.max <= newStakeThreshold.min) revert StakeThresholdMaxLessOrEqualMin();
        emit ManagedStakeThresholdChanged(chainId, newStakeThreshold.min, newStakeThreshold.max, newStakeThreshold.activated);
        _scannerStakeThresholds[chainId] = newStakeThreshold;
    }
    function getManagedStakeThreshold(uint256 managedId) public view returns (StakeThreshold memory) {
        return _scannerStakeThresholds[_scannerPoolChainId[managedId]];
    }
    function getTotalManagedSubjects(uint256 subject) public view virtual override returns (uint256) {
        return _enabledScanners[subject];
    }
    function setRegistrationDelay(uint256 delay) external onlyRole(SCANNER_POOL_ADMIN_ROLE) {
        _setRegistrationDelay(delay);
    }
    function _setRegistrationDelay(uint256 delay) internal {
        if (delay == 0) revert ZeroAmount("delay");
        registrationDelay = delay;
        emit RegistrationDelaySet(delay);
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    function _msgSender() internal view virtual override(BaseComponentUpgradeable, ContextUpgradeable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(BaseComponentUpgradeable, ContextUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }
    function ownerOf(uint256 subject) public view virtual override(IStakeSubject, ERC721Upgradeable) returns (address) {
        return super.ownerOf(subject);
    }
    uint256[44] private __gap;
}