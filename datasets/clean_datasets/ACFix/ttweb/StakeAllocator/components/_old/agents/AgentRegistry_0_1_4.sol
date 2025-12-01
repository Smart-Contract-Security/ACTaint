pragma solidity ^0.8.9;
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
abstract contract Multicall {
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
}
interface IERC1822ProxiableUpgradeable {
    function proxiableUUID() external view returns (bytes32);
}
interface IBeaconUpgradeable {
    function implementation() external view returns (address);
}
library AddressUpgradeable {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }
    struct BooleanSlot {
        bool value;
    }
    struct Bytes32Slot {
        bytes32 value;
    }
    struct Uint256Slot {
        uint256 value;
    }
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}
abstract contract Initializable {
    uint8 private _initialized;
    bool private _initializing;
    event Initialized(uint8 version);
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }
    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    event Upgraded(address indexed implementation);
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    event AdminChanged(address previousAdmin, address newAdmin);
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    event BeaconUpgraded(address indexed beacon);
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }
    uint256[50] private __gap;
}
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }
    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    address private immutable __self = address(this);
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }
    function _authorizeUpgrade(address newImplementation) internal virtual;
    uint256[50] private __gap;
}
bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);
bytes32 constant ROUTER_ADMIN_ROLE  = keccak256("ROUTER_ADMIN_ROLE");
bytes32 constant ENS_MANAGER_ROLE   = keccak256("ENS_MANAGER_ROLE");
bytes32 constant UPGRADER_ROLE      = keccak256("UPGRADER_ROLE");
bytes32 constant AGENT_ADMIN_ROLE   = keccak256("AGENT_ADMIN_ROLE");
bytes32 constant SCANNER_ADMIN_ROLE = keccak256("SCANNER_ADMIN_ROLE");
bytes32 constant DISPATCHER_ROLE    = keccak256("DISPATCHER_ROLE");
bytes32 constant SLASHER_ROLE       = keccak256("SLASHER_ROLE");
bytes32 constant SWEEPER_ROLE       = keccak256("SWEEPER_ROLE");
bytes32 constant REWARDS_ADMIN_ROLE      = keccak256("REWARDS_ADMIN_ROLE");
bytes32 constant SLASHING_ARBITER_ROLE      = keccak256("SLASHING_ARBITER_ROLE");
bytes32 constant STAKING_ADMIN_ROLE      = keccak256("STAKING_ADMIN_ROLE");
bytes32 constant SCANNER_VERSION_ROLE = keccak256("SCANNER_VERSION_ROLE");
bytes32 constant SCANNER_BETA_VERSION_ROLE = keccak256("SCANNER_BETA_VERSION_ROLE");
interface IAccessControl {
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }
    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}
interface IERC165Upgradeable {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
library ERC165CheckerUpgradeable {
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;
    function supportsERC165(address account) internal view returns (bool) {
        return
            _supportsERC165Interface(account, type(IERC165Upgradeable).interfaceId) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        return supportsERC165(account) && _supportsERC165Interface(account, interfaceId);
    }
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool[] memory)
    {
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);
        if (supportsERC165(account)) {
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }
        return interfaceIdsSupported;
    }
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        if (!supportsERC165(account)) {
            return false;
        }
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }
        return true;
    }
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        bytes memory encodedParams = abi.encodeWithSelector(IERC165Upgradeable.supportsInterface.selector, interfaceId);
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(encodedParams);
        if (result.length < 32) return false;
        return success && abi.decode(result, (bool));
    }
}
error ZeroAddress(string name);
error ZeroAmount(string name);
error EmptyArray(string name);
error EmptyString(string name);
error UnorderedArray(string name);
error DifferentLenghtArray(string array1, string array2);
error ArrayTooBig(uint256 lenght, uint256 max);
error StringTooLarge(uint256 length, uint256 max);
error UnsupportedInterface(string name);
error SenderNotOwner(address sender, uint256 ownedId);
error DoesNotHaveAccess(address sender, string access);
error DoesNotHavePermission(address sender, uint8 permission, uint256 id);
abstract contract AccessManagedUpgradeable is ContextUpgradeable {
    using ERC165CheckerUpgradeable for address;
    IAccessControl private _accessControl;
    event AccessManagerUpdated(address indexed newAddressManager);
    error MissingRole(bytes32 role, address account);
    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, _msgSender())) {
            revert MissingRole(role, _msgSender());
        }
        _;
    }
    function __AccessManaged_init(address manager) internal initializer {
        if (!manager.supportsInterface(type(IAccessControl).interfaceId)) revert UnsupportedInterface("IAccessControl");
        _accessControl = IAccessControl(manager);
        emit AccessManagerUpdated(manager);
    }
    function hasRole(bytes32 role, address account) internal view returns (bool) {
        return _accessControl.hasRole(role, account);
    }
    function setAccessManager(address newManager) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!newManager.supportsInterface(type(IAccessControl).interfaceId)) revert UnsupportedInterface("IAccessControl");
        _accessControl = IAccessControl(newManager);
        emit AccessManagerUpdated(newManager);
    }
    uint256[49] private __gap;
}
interface IVersioned {
    function version() external returns(string memory v);
}
abstract contract ForwardedContext is ContextUpgradeable {
    address private immutable _trustedForwarder;
    uint256 private constant ADDRESS_SIZE_BYTES = 20;
    constructor(address trustedForwarder) {
        _trustedForwarder = trustedForwarder;
    }
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }
    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            return address(bytes20(msg.data[msg.data.length - ADDRESS_SIZE_BYTES: msg.data.length]));
        } else {
            return super._msgSender();
        }
    }
    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - ADDRESS_SIZE_BYTES];
        } else {
            return super._msgData();
        }
    }
}
interface IRouter {
    function hookHandler(bytes calldata) external;
}
abstract contract RoutedUpgradeable is AccessManagedUpgradeable {
    IRouter private _router;
    event RouterUpdated(address indexed router);
    function __Routed_init(address router) internal initializer {
        if (router == address(0)) revert ZeroAddress("router");
        _router = IRouter(router);
        emit RouterUpdated(router);
    }
    function _emitHook(bytes memory data) internal {
        if (address(_router) != address(0)) {
            try _router.hookHandler(data) {}
            catch {}
        }
    }
    function setRouter(address newRouter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRouter == address(0)) revert ZeroAddress("newRouter");
        _router = IRouter(newRouter);
        emit RouterUpdated(newRouter);
    }
    uint256[49] private __gap;
}
interface ENS {
    event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);
    event Transfer(bytes32 indexed node, address owner);
    event NewResolver(bytes32 indexed node, address resolver);
    event NewTTL(bytes32 indexed node, uint64 ttl);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function setRecord(bytes32 node, address owner, address resolver, uint64 ttl) external virtual;
    function setSubnodeRecord(bytes32 node, bytes32 label, address owner, address resolver, uint64 ttl) external virtual;
    function setSubnodeOwner(bytes32 node, bytes32 label, address owner) external virtual returns(bytes32);
    function setResolver(bytes32 node, address resolver) external virtual;
    function setOwner(bytes32 node, address owner) external virtual;
    function setTTL(bytes32 node, uint64 ttl) external virtual;
    function setApprovalForAll(address operator, bool approved) external virtual;
    function owner(bytes32 node) external virtual view returns (address);
    function resolver(bytes32 node) external virtual view returns (address);
    function ttl(bytes32 node) external virtual view returns (uint64);
    function recordExists(bytes32 node) external virtual view returns (bool);
    function isApprovedForAll(address owner, address operator) external virtual view returns (bool);
}
interface IReverseRegistrar {
    function ADDR_REVERSE_NODE() external view returns (bytes32);
    function ens() external view returns (ENS);
    function defaultResolver() external view returns (address);
    function claim(address) external returns (bytes32);
    function claimWithResolver(address, address) external returns (bytes32);
    function setName(string calldata) external returns (bytes32);
    function node(address) external pure returns (bytes32);
}
library ENSReverseRegistration {
    bytes32 internal constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;
    function setName(address ensregistry, string calldata ensname) internal {
        IReverseRegistrar(ENS(ensregistry).owner(ADDR_REVERSE_NODE)).setName(ensname);
    }
}
abstract contract BaseComponentUpgradeable is
    ForwardedContext,
    AccessManagedUpgradeable,
    RoutedUpgradeable,
    Multicall,
    UUPSUpgradeable,
    IVersioned
{
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {
    }
    function setName(address ensRegistry, string calldata ensName) public onlyRole(ENS_MANAGER_ROLE) {
        ENSReverseRegistration.setName(ensRegistry, ensName);
    }
    function _msgSender() internal view virtual override(ContextUpgradeable, ForwardedContext) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ContextUpgradeable, ForwardedContext) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[50] private __gap;
}
interface IERC721Upgradeable is IERC165Upgradeable {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
interface IERC721ReceiverUpgradeable {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }
    function __ERC165_init_unchained() internal onlyInitializing {
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    string private _name;
    string private _symbol;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }
    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
        );
        _approve(to, tokenId);
    }
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);
        return _tokenApprovals[tokenId];
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _transfer(from, to, tokenId);
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        _beforeTokenTransfer(address(0), to, tokenId);
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
        _afterTokenTransfer(address(0), to, tokenId);
    }
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        _beforeTokenTransfer(owner, address(0), tokenId);
        _approve(address(0), tokenId);
        _balances[owner] -= 1;
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
        _afterTokenTransfer(owner, address(0), tokenId);
    }
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        _beforeTokenTransfer(from, to, tokenId);
        _approve(address(0), tokenId);
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
        _afterTokenTransfer(from, to, tokenId);
    }
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
    uint256[44] private __gap;
}
interface IStakeSubject {
    struct StakeThreshold {
        uint256 min;
        uint256 max;
        bool activated;
    }
    function getStakeThreshold(uint256 subject) external view returns (StakeThreshold memory);
    function isStakedOverMin(uint256 subject) external view returns (bool);
    function isRegistered(uint256 subjectId) external view returns(bool);
}
interface IStakeController {
    event StakeSubjectHandlerChanged(address newHandler, address oldHandler);
    function setStakeSubjectHandler(uint8 subjectType, IStakeSubject subjectHandler) external;
    function activeStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function maxStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function minStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function totalStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function maxSlashableStakePercent() external view returns(uint256);
    function isStakeActivatedFor(uint8 subjectType, uint256 subject) external view returns(bool);
}
uint8 constant SCANNER_SUBJECT = 0;
uint8 constant AGENT_SUBJECT = 1;
contract SubjectTypeValidator {
    error InvalidSubjectType(uint8 subjectType);
    modifier onlyValidSubjectType(uint8 subjectType) {
        if (
            subjectType != SCANNER_SUBJECT &&
            subjectType != AGENT_SUBJECT
        ) revert InvalidSubjectType(subjectType);
        _;
    }
}
abstract contract StakeSubjectUpgradeable is AccessManagedUpgradeable, IStakeSubject {
    IStakeController private _stakeController;
    event StakeControllerUpdated(address indexed newstakeController);
    error StakeThresholdMaxLessOrEqualMin();
    error StakedUnderMinimum(uint256 subject);
    function __StakeAwareUpgradeable_init(address stakeController) internal initializer {
        _setStakeController(stakeController);
    }
    function setStakeController(address stakeController) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setStakeController(stakeController);
    }
    function getStakeController() public view returns(IStakeController) {
        return _stakeController;
    }
    function _setStakeController(address stakeController) private {
        if (stakeController == address(0)) revert ZeroAddress("stakeController");
        _stakeController = IStakeController(stakeController);
        emit StakeControllerUpdated(stakeController);
    }
    function isStakedOverMin(uint256 subject) external virtual override view returns(bool) {
        return _isStakedOverMin(subject);
    }
    function _isStakedOverMin(uint256 subject) internal virtual view returns(bool);
    uint256[4] private __gap;
}
contract FrontRunningProtection {
    mapping(bytes32 => uint256) private _commits;
    error CommitNotReady();
    error CommitAlreadyExists();
    modifier frontrunProtected(bytes32 commit, uint256 duration) {
        uint256 timestamp = _commits[commit];
        if (!(duration == 0 || (timestamp != 0 && timestamp + duration <= block.timestamp))) revert CommitNotReady();
        delete _commits[commit];
        _;
    }
    function getCommitTimestamp(bytes32 commit) external view returns(uint256) {
        return _commits[commit];
    }
    function _frontrunCommit(bytes32 commit) internal {
        if (_commits[commit] != 0) revert CommitAlreadyExists();
        _commits[commit] = block.timestamp;
    }
}
abstract contract AgentRegistryCore is
    BaseComponentUpgradeable,
    FrontRunningProtection,
    ERC721Upgradeable,
    StakeSubjectUpgradeable
{
    StakeThreshold private _stakeThreshold; 
    uint256 public frontRunningDelay;
    event AgentCommitted(bytes32 indexed commit);
    event AgentUpdated(uint256 indexed agentId, address indexed by, string metadata, uint256[] chainIds);
    event StakeThresholdChanged(uint256 min, uint256 max, bool activated);
    event FrontRunningDelaySet(uint256 delay);
    modifier onlyOwnerOf(uint256 agentId) {
        if (_msgSender() != ownerOf(agentId)) revert SenderNotOwner(_msgSender(), agentId);
        _;
    }
    modifier onlySorted(uint256[] memory array) {
        if (array.length == 0 ) revert EmptyArray("chainIds");
        for (uint256 i = 1; i < array.length; i++ ) {
            if (array[i] <= array[i-1]) revert UnorderedArray("chainIds");
        }
        _;
    }
    function prepareAgent(bytes32 commit) public {
        _frontrunCommit(commit);
    }
    function createAgent(uint256 agentId, address owner, string calldata metadata, uint256[] calldata chainIds)
    public
        onlySorted(chainIds)
        frontrunProtected(keccak256(abi.encodePacked(agentId, owner, metadata, chainIds)), frontRunningDelay)
    {
        _mint(owner, agentId);
        _beforeAgentUpdate(agentId, metadata, chainIds);
        _agentUpdate(agentId, metadata, chainIds);
        _afterAgentUpdate(agentId, metadata, chainIds);
    }
    function isRegistered(uint256 agentId) public view returns(bool) {
        return _exists(agentId);
    }
    function updateAgent(uint256 agentId, string calldata metadata, uint256[] calldata chainIds)
    public
        onlyOwnerOf(agentId)
        onlySorted(chainIds)
    {
        _beforeAgentUpdate(agentId, metadata, chainIds);
        _agentUpdate(agentId, metadata, chainIds);
        _afterAgentUpdate(agentId, metadata, chainIds);
    }
    function setStakeThreshold(StakeThreshold memory newStakeThreshold) external onlyRole(AGENT_ADMIN_ROLE) {
        if (newStakeThreshold.max <= newStakeThreshold.min) revert StakeThresholdMaxLessOrEqualMin();
        _stakeThreshold = newStakeThreshold;
        emit StakeThresholdChanged(newStakeThreshold.min, newStakeThreshold.max, newStakeThreshold.activated);
    }
    function getStakeThreshold(uint256 ) public override view returns (StakeThreshold memory) {
        return _stakeThreshold;
    }
    function _isStakedOverMin(uint256 subject) internal override view returns(bool) {
        if (address(getStakeController()) == address(0)) {
            return true;
        }
        return getStakeController().activeStakeFor(AGENT_SUBJECT, subject) >= _stakeThreshold.min && _exists(subject);
    }
    function setFrontRunningDelay(uint256 delay) external onlyRole(AGENT_ADMIN_ROLE) {
        frontRunningDelay = delay;
        emit FrontRunningDelaySet(delay);
    }
    function _beforeAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual {
    }
    function _agentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual {
        emit AgentUpdated(agentId, _msgSender(), newMetadata, newChainIds);
    }
    function _afterAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual {
        _emitHook(abi.encodeWithSignature("hook_afterAgentUpdate(uint256,string,uint256[])", agentId, newMetadata, newChainIds));
    }
    function _msgSender() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[41] private __gap; 
}
library BitMaps {
    struct BitMap {
        mapping(uint256 => uint256) _data;
    }
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }
    function setTo(
        BitMap storage bitmap,
        uint256 index,
        bool value
    ) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}
abstract contract AgentRegistryEnable is AgentRegistryCore {
    using BitMaps for BitMaps.BitMap;
    enum Permission {
        ADMIN,
        OWNER,
        length
    }
    mapping(uint256 => BitMaps.BitMap) private _disabled;
    event AgentEnabled(uint256 indexed agentId, bool indexed enabled, Permission permission, bool value);
    function isEnabled(uint256 agentId) public view virtual returns (bool) {
        return isRegistered(agentId) &&
            getDisableFlags(agentId) == 0 &&
            _isStakedOverMin(agentId); 
    }
    function enableAgent(uint256 agentId, Permission permission) public virtual {
        if (!_isStakedOverMin(agentId)) revert StakedUnderMinimum(agentId);
        if (!_hasPermission(agentId, permission)) revert DoesNotHavePermission(_msgSender(), uint8(permission), agentId);
        _enable(agentId, permission, true);
    }
    function disableAgent(uint256 agentId, Permission permission) public virtual {
        if (!_hasPermission(agentId, permission)) revert DoesNotHavePermission(_msgSender(), uint8(permission), agentId);
        _enable(agentId, permission, false);
    }
    function getDisableFlags(uint256 agentId) public view returns (uint256) {
        return _disabled[agentId]._data[0];
    }
    function _hasPermission(uint256 agentId, Permission permission) internal view returns (bool) {
        if (permission == Permission.ADMIN) { return hasRole(AGENT_ADMIN_ROLE, _msgSender()); }
        if (permission == Permission.OWNER) { return _msgSender() == ownerOf(agentId); }
        return false;
    }
    function _enable(uint256 agentId, Permission permission, bool enable) internal {
        _beforeAgentEnable(agentId, permission, enable);
        _agentEnable(agentId, permission, enable);
        _afterAgentEnable(agentId, permission, enable);
    }
    function _beforeAgentEnable(uint256 agentId, Permission permission, bool value) internal virtual {
    }
    function _agentEnable(uint256 agentId, Permission permission, bool value) internal virtual {
        _disabled[agentId].setTo(uint8(permission), !value);
        emit AgentEnabled(agentId, isEnabled(agentId), permission, value);
    }
    function _afterAgentEnable(uint256 agentId, Permission permission, bool value) internal virtual {
        _emitHook(abi.encodeWithSignature("hook_afterAgentEnable(uint256,uint8,bool)", agentId, uint8(permission), value));
    }
    function _msgSender() internal view virtual override(AgentRegistryCore) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(AgentRegistryCore) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[49] private __gap;
}
library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping(bytes32 => uint256) _indexes;
    }
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];
                set._values[toDeleteIndex] = lastValue;
                set._indexes[lastValue] = valueIndex; 
            }
            set._values.pop();
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }
    struct Bytes32Set {
        Set _inner;
    }
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }
    struct AddressSet {
        Set _inner;
    }
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;
        assembly {
            result := store
        }
        return result;
    }
    struct UintSet {
        Set _inner;
    }
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;
        assembly {
            result := store
        }
        return result;
    }
}
abstract contract AgentRegistryMetadata is AgentRegistryCore {
    struct AgentMetadata {
        uint256 version;
        string metadata;
        uint256[] chainIds;
    }
    mapping(uint256 => AgentMetadata) private _agentMetadata;
    mapping(bytes32 => bool) private _agentMetadataUniqueness;
    error MetadataNotUnique(bytes32 hash);
    function getAgent(uint256 agentId)
        public view
        returns (bool registered, address owner,uint256 agentVersion, string memory metadata, uint256[] memory chainIds) {
        bool exists = _exists(agentId);
        return (
            exists,
            exists ? ownerOf(agentId) : address(0),
            _agentMetadata[agentId].version,
            _agentMetadata[agentId].metadata,
            _agentMetadata[agentId].chainIds
        );
    }
    function _agentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual override {
        super._agentUpdate(agentId, newMetadata, newChainIds);
        bytes32 oldHash = keccak256(bytes(_agentMetadata[agentId].metadata));
        bytes32 newHash = keccak256(bytes(newMetadata));
        if (_agentMetadataUniqueness[newHash]) revert MetadataNotUnique(newHash);
        _agentMetadataUniqueness[newHash] = true;
        _agentMetadataUniqueness[oldHash] = false;
        uint256 version = _agentMetadata[agentId].version + 1;
        _agentMetadata[agentId] = AgentMetadata({ version: version, metadata: newMetadata, chainIds: newChainIds });
    }
    uint256[48] private __gap;
}
abstract contract AgentRegistryEnumerable is AgentRegistryMetadata {
    using EnumerableSet for EnumerableSet.UintSet;
    EnumerableSet.UintSet private _allAgents;
    mapping(uint256 => EnumerableSet.UintSet) private _chainAgents;
    function getAgentCount() public view returns (uint256) {
        return _allAgents.length();
    }
    function getAgentByIndex(uint256 index) public view returns (uint256) {
        return _allAgents.at(index);
    }
    function getAgentCountByChain(uint256 chainId) public view returns (uint256) {
        return _chainAgents[chainId].length();
    }
    function getAgentByChainAndIndex(uint256 chainId, uint256 index) public view returns (uint256) {
        return _chainAgents[chainId].at(index);
    }
    function _beforeAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual override {
        super._beforeAgentUpdate(agentId, newMetadata, newChainIds);
        (,,uint256 version,, uint256[] memory oldChainIds) = getAgent(agentId);
        if (version == 0) { _allAgents.add(agentId); } 
        uint256 i = 0;
        uint256 j = 0;
        while (i < oldChainIds.length || j < newChainIds.length) {
            if (i == oldChainIds.length) { 
                _chainAgents[newChainIds[j++]].add(agentId);
            } else if (j == newChainIds.length) { 
                _chainAgents[oldChainIds[i++]].remove(agentId);
            } else if (oldChainIds[i] < newChainIds[j]) { 
                _chainAgents[oldChainIds[i++]].remove(agentId);
            } else if (oldChainIds[i] > newChainIds[j]) { 
                _chainAgents[newChainIds[j++]].add(agentId);
            } else { 
                i++;
                j++;
            }
        }
    }
    uint256[48] private __gap;
}
contract AgentRegistry_0_1_4 is
    BaseComponentUpgradeable,
    AgentRegistryCore,
    AgentRegistryEnable,
    AgentRegistryMetadata,
    AgentRegistryEnumerable
{
    string public constant version = "0.1.4";
    constructor(address forwarder) initializer ForwardedContext(forwarder) {}
    function initialize(
        address __manager,
        address __router,
        string calldata __name,
        string calldata __symbol
    ) public initializer {
        __AccessManaged_init(__manager);
        __Routed_init(__router);
        __UUPSUpgradeable_init();
        __ERC721_init(__name, __symbol);
    }
    function getAgentState(uint256 agentId)
        public view
        returns (
            bool registered,
            address owner,
            uint256 agentVersion,
            string memory metadata,
            uint256[] memory chainIds,
            bool enabled,
            uint256 disabledFlags
        ) {
        (registered, owner, agentVersion, metadata, chainIds) = getAgent(agentId);
        return (
            registered,
            owner,
            agentVersion,
            metadata,
            chainIds,
            isEnabled(agentId),
            getDisableFlags(agentId)
        );
    }
    function _beforeAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual override(AgentRegistryCore, AgentRegistryEnumerable) {
        super._beforeAgentUpdate(agentId, newMetadata, newChainIds);
    }
    function _agentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual override(AgentRegistryCore, AgentRegistryMetadata) {
        super._agentUpdate(agentId, newMetadata, newChainIds);
    }
    function _msgSender() internal view virtual override(BaseComponentUpgradeable, AgentRegistryCore, AgentRegistryEnable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(BaseComponentUpgradeable, AgentRegistryCore, AgentRegistryEnable) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[50] private __gap;
}