pragma solidity ^0.8.4;
interface IStakeSubject {
    struct StakeThreshold {
        uint256 min;
        uint256 max;
        bool activated;
    }
    function getStakeThreshold(uint256 subject) external view returns (StakeThreshold memory);
    function isStakedOverMin(uint256 subject) external view returns (bool);
}
interface IStakeController {
    event StakeSubjectHandlerChanged(address newHandler, address oldHandler);
    function setStakeSubjectHandler(uint8 subjectType, IStakeSubject subjectHandler) external;
    function activeStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function maxStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function minStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256);
    function isStakeActivatedFor(uint8 subjectType, uint256 subject) external view returns(bool);
}
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
bytes32 constant REWARDS_ADMIN      = keccak256("REWARDS_ADMIN_ROLE");
bytes32 constant SCANNER_VERSION_ROLE = keccak256("SCANNER_VERSION_ROLE");
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
error UnorderedArray(string name);
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
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
interface IERC2612 is IERC20Permit {}
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
library SafeERC20 {
    using Address for address;
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
library ERC165Checker {
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;
    function supportsERC165(address account) internal view returns (bool) {
        return
            _supportsERC165Interface(account, type(IERC165).interfaceId) &&
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
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(encodedParams);
        if (result.length < 32) return false;
        return success && abi.decode(result, (bool));
    }
}
library Math {
    enum Rounding {
        Down, 
        Up, 
        Zero 
    }
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a & b) + (a ^ b) / 2;
    }
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a == 0 ? 0 : (a - 1) / b + 1;
    }
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0; 
            uint256 prod1; 
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            if (prod1 == 0) {
                return prod0 / denominator;
            }
            require(denominator > prod1);
            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;
            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            inverse *= 2 - denominator * inverse; 
            result = prod0 * inverse;
            return result;
        }
    }
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 result = 1;
        uint256 x = a;
        if (x >> 128 > 0) {
            x >>= 128;
            result <<= 64;
        }
        if (x >> 64 > 0) {
            x >>= 64;
            result <<= 32;
        }
        if (x >> 32 > 0) {
            x >>= 32;
            result <<= 16;
        }
        if (x >> 16 > 0) {
            x >>= 16;
            result <<= 8;
        }
        if (x >> 8 > 0) {
            x >>= 8;
            result <<= 4;
        }
        if (x >> 4 > 0) {
            x >>= 4;
            result <<= 2;
        }
        if (x >> 2 > 0) {
            result <<= 1;
        }
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (rounding == Rounding.Up && result * result < a) {
            result += 1;
        }
        return result;
    }
}
library SafeCast {
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }
    function toInt248(int256 value) internal pure returns (int248) {
        require(value >= type(int248).min && value <= type(int248).max, "SafeCast: value doesn't fit in 248 bits");
        return int248(value);
    }
    function toInt240(int256 value) internal pure returns (int240) {
        require(value >= type(int240).min && value <= type(int240).max, "SafeCast: value doesn't fit in 240 bits");
        return int240(value);
    }
    function toInt232(int256 value) internal pure returns (int232) {
        require(value >= type(int232).min && value <= type(int232).max, "SafeCast: value doesn't fit in 232 bits");
        return int232(value);
    }
    function toInt224(int256 value) internal pure returns (int224) {
        require(value >= type(int224).min && value <= type(int224).max, "SafeCast: value doesn't fit in 224 bits");
        return int224(value);
    }
    function toInt216(int256 value) internal pure returns (int216) {
        require(value >= type(int216).min && value <= type(int216).max, "SafeCast: value doesn't fit in 216 bits");
        return int216(value);
    }
    function toInt208(int256 value) internal pure returns (int208) {
        require(value >= type(int208).min && value <= type(int208).max, "SafeCast: value doesn't fit in 208 bits");
        return int208(value);
    }
    function toInt200(int256 value) internal pure returns (int200) {
        require(value >= type(int200).min && value <= type(int200).max, "SafeCast: value doesn't fit in 200 bits");
        return int200(value);
    }
    function toInt192(int256 value) internal pure returns (int192) {
        require(value >= type(int192).min && value <= type(int192).max, "SafeCast: value doesn't fit in 192 bits");
        return int192(value);
    }
    function toInt184(int256 value) internal pure returns (int184) {
        require(value >= type(int184).min && value <= type(int184).max, "SafeCast: value doesn't fit in 184 bits");
        return int184(value);
    }
    function toInt176(int256 value) internal pure returns (int176) {
        require(value >= type(int176).min && value <= type(int176).max, "SafeCast: value doesn't fit in 176 bits");
        return int176(value);
    }
    function toInt168(int256 value) internal pure returns (int168) {
        require(value >= type(int168).min && value <= type(int168).max, "SafeCast: value doesn't fit in 168 bits");
        return int168(value);
    }
    function toInt160(int256 value) internal pure returns (int160) {
        require(value >= type(int160).min && value <= type(int160).max, "SafeCast: value doesn't fit in 160 bits");
        return int160(value);
    }
    function toInt152(int256 value) internal pure returns (int152) {
        require(value >= type(int152).min && value <= type(int152).max, "SafeCast: value doesn't fit in 152 bits");
        return int152(value);
    }
    function toInt144(int256 value) internal pure returns (int144) {
        require(value >= type(int144).min && value <= type(int144).max, "SafeCast: value doesn't fit in 144 bits");
        return int144(value);
    }
    function toInt136(int256 value) internal pure returns (int136) {
        require(value >= type(int136).min && value <= type(int136).max, "SafeCast: value doesn't fit in 136 bits");
        return int136(value);
    }
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }
    function toInt120(int256 value) internal pure returns (int120) {
        require(value >= type(int120).min && value <= type(int120).max, "SafeCast: value doesn't fit in 120 bits");
        return int120(value);
    }
    function toInt112(int256 value) internal pure returns (int112) {
        require(value >= type(int112).min && value <= type(int112).max, "SafeCast: value doesn't fit in 112 bits");
        return int112(value);
    }
    function toInt104(int256 value) internal pure returns (int104) {
        require(value >= type(int104).min && value <= type(int104).max, "SafeCast: value doesn't fit in 104 bits");
        return int104(value);
    }
    function toInt96(int256 value) internal pure returns (int96) {
        require(value >= type(int96).min && value <= type(int96).max, "SafeCast: value doesn't fit in 96 bits");
        return int96(value);
    }
    function toInt88(int256 value) internal pure returns (int88) {
        require(value >= type(int88).min && value <= type(int88).max, "SafeCast: value doesn't fit in 88 bits");
        return int88(value);
    }
    function toInt80(int256 value) internal pure returns (int80) {
        require(value >= type(int80).min && value <= type(int80).max, "SafeCast: value doesn't fit in 80 bits");
        return int80(value);
    }
    function toInt72(int256 value) internal pure returns (int72) {
        require(value >= type(int72).min && value <= type(int72).max, "SafeCast: value doesn't fit in 72 bits");
        return int72(value);
    }
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }
    function toInt56(int256 value) internal pure returns (int56) {
        require(value >= type(int56).min && value <= type(int56).max, "SafeCast: value doesn't fit in 56 bits");
        return int56(value);
    }
    function toInt48(int256 value) internal pure returns (int48) {
        require(value >= type(int48).min && value <= type(int48).max, "SafeCast: value doesn't fit in 48 bits");
        return int48(value);
    }
    function toInt40(int256 value) internal pure returns (int40) {
        require(value >= type(int40).min && value <= type(int40).max, "SafeCast: value doesn't fit in 40 bits");
        return int40(value);
    }
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }
    function toInt24(int256 value) internal pure returns (int24) {
        require(value >= type(int24).min && value <= type(int24).max, "SafeCast: value doesn't fit in 24 bits");
        return int24(value);
    }
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}
library Timers {
    struct Timestamp {
        uint64 _deadline;
    }
    function getDeadline(Timestamp memory timer) internal pure returns (uint64) {
        return timer._deadline;
    }
    function setDeadline(Timestamp storage timer, uint64 timestamp) internal {
        timer._deadline = timestamp;
    }
    function reset(Timestamp storage timer) internal {
        timer._deadline = 0;
    }
    function isUnset(Timestamp memory timer) internal pure returns (bool) {
        return timer._deadline == 0;
    }
    function isStarted(Timestamp memory timer) internal pure returns (bool) {
        return timer._deadline > 0;
    }
    function isPending(Timestamp memory timer) internal view returns (bool) {
        return timer._deadline > block.timestamp;
    }
    function isExpired(Timestamp memory timer) internal view returns (bool) {
        return isStarted(timer) && timer._deadline <= block.timestamp;
    }
    struct BlockNumber {
        uint64 _deadline;
    }
    function getDeadline(BlockNumber memory timer) internal pure returns (uint64) {
        return timer._deadline;
    }
    function setDeadline(BlockNumber storage timer, uint64 timestamp) internal {
        timer._deadline = timestamp;
    }
    function reset(BlockNumber storage timer) internal {
        timer._deadline = 0;
    }
    function isUnset(BlockNumber memory timer) internal pure returns (bool) {
        return timer._deadline == 0;
    }
    function isStarted(BlockNumber memory timer) internal pure returns (bool) {
        return timer._deadline > 0;
    }
    function isPending(BlockNumber memory timer) internal view returns (bool) {
        return timer._deadline > block.number;
    }
    function isExpired(BlockNumber memory timer) internal view returns (bool) {
        return isStarted(timer) && timer._deadline <= block.number;
    }
}
interface IERC1155Upgradeable is IERC165Upgradeable {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}
interface IERC1155MetadataURIUpgradeable is IERC1155Upgradeable {
    function uri(uint256 id) external view returns (string memory);
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
contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable, IERC1155MetadataURIUpgradeable {
    using AddressUpgradeable for address;
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    string private _uri;
    function __ERC1155_init(string memory uri_) internal onlyInitializing {
        __ERC1155_init_unchained(uri_);
    }
    function __ERC1155_init_unchained(string memory uri_) internal onlyInitializing {
        _setURI(uri_);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        emit TransferSingle(operator, from, to, id, amount);
        _afterTokenTransfer(operator, from, to, ids, amounts, data);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }
        emit TransferBatch(operator, from, to, ids, amounts);
        _afterTokenTransfer(operator, from, to, ids, amounts, data);
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);
        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(operator, address(0), to, ids, amounts);
        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);
        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        emit TransferSingle(operator, from, address(0), id, amount);
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = _msgSender();
        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }
        emit TransferBatch(operator, from, address(0), ids, amounts);
        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }
    uint256[47] private __gap;
}
abstract contract ERC1155SupplyUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155Supply_init() internal onlyInitializing {
    }
    function __ERC1155Supply_init_unchained() internal onlyInitializing {
    }
    mapping(uint256 => uint256) private _totalSupply;
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }
    function exists(uint256 id) public view virtual returns (bool) {
        return ERC1155SupplyUpgradeable.totalSupply(id) > 0;
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }
        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 amount = amounts[i];
                uint256 supply = _totalSupply[id];
                require(supply >= amount, "ERC1155: burn amount exceeds totalSupply");
                unchecked {
                    _totalSupply[id] = supply - amount;
                }
            }
        }
    }
    uint256[49] private __gap;
}
library FortaStakingUtils {
    function subjectToActive(uint8 subjectType, uint256 subject) internal pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(subjectType, subject))) << 9 | uint16(256)) | uint256(subjectType);
    }
    function subjectToInactive(uint8 subjectType, uint256 subject) internal pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(subjectType, subject))) << 9) | uint256(subjectType);
    }
    function activeToInactive(uint256 activeSharesId) internal pure returns (uint256) {
        return activeSharesId & (~uint256(1 << 8));
    }
    function inactiveToActive(uint256 inactiveSharesId) internal pure returns (uint256) {
        return inactiveSharesId | (1 << 8);
    }
    function isActive(uint256 sharesId) internal pure returns(bool) {
        return sharesId & (1 << 8) == 256;
    }
    function subjectTypeOfShares(uint256 sharesId) internal pure returns(uint8) {
        return uint8(sharesId);
    }
}
library Distributions {
    struct Balances {
        mapping(uint256 => uint256) _balances;
        uint256 _totalSupply;
    }
    function balanceOf(Balances storage self, uint256 subjectId) internal view returns (uint256) {
        return self._balances[subjectId];
    }
    function totalSupply(Balances storage self) internal view returns (uint256) {
        return self._totalSupply;
    }
    function mint(Balances storage self, uint256 subjectId, uint256 amount) internal {
        self._balances[subjectId] += amount;
        self._totalSupply += amount;
    }
    function burn(Balances storage self, uint256 subjectId, uint256 amount) internal {
        self._balances[subjectId] -= amount;
        self._totalSupply -= amount;
    }
    function transfer(Balances storage self, uint256 from, uint256 to, uint256 amount) internal {
        self._balances[from] -= amount;
        self._balances[to] += amount;
    }
    struct SignedBalances {
        mapping(address => int256) _balances;
        int256 _totalSupply;
    }
    function balanceOf(SignedBalances storage self, address account) internal view returns (int256) {
        return self._balances[account];
    }
    function totalSupply(SignedBalances storage self) internal view returns (int256) {
        return self._totalSupply;
    }
    function mint(SignedBalances storage self, address account, int256 amount) internal {
        if (account == address(0)) revert ZeroAddress("mint");
        self._balances[account] += amount;
        self._totalSupply += amount;
    }
    function burn(SignedBalances storage self, address account, int256 amount) internal {
        if(account == address(0)) revert ZeroAddress("burn");
        self._balances[account] -= amount;
        self._totalSupply -= amount;
    }
    function transfer(SignedBalances storage self, address from, address to, int256 amount) internal {
        if (from == address(0)) revert ZeroAddress("from");
        if (to == address(0)) revert ZeroAddress("to");
        self._balances[from] -= amount;
        self._balances[to] += amount;
    }
}
library FullMath {
    error DenominatorLessOrEqualThanProd();
    function mulDiv(uint256 numerator, uint256 denominator, uint256 target) internal pure returns (uint256 partialAmount) {
        uint256 prod0; 
        uint256 prod1; 
        assembly {
            let mm := mulmod(target, numerator, not(0))
            prod0 := mul(target, numerator)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
        if (prod1 == 0) {
            assembly {
                partialAmount := div(prod0, denominator)
            }
            return partialAmount;
        }
        if (denominator <= prod1) revert DenominatorLessOrEqualThanProd();
        assembly {
            let remainder := mulmod(target, numerator, denominator)
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
            let twos := and(sub(0, denominator), denominator)
            denominator := div(denominator, twos)
            prod0 := div(prod0, twos)
            twos := add(div(sub(0, twos), twos), 1)
            prod0 := or(prod0, mul(prod1, twos))
            let inv := mul(3, mul(denominator, denominator))
            inv := mul(inv, sub(2, mul(denominator, inv))) 
            inv := mul(inv, sub(2, mul(denominator, inv))) 
            inv := mul(inv, sub(2, mul(denominator, inv))) 
            inv := mul(inv, sub(2, mul(denominator, inv))) 
            inv := mul(inv, sub(2, mul(denominator, inv))) 
            inv := mul(inv, sub(2, mul(denominator, inv))) 
            partialAmount := mul(prod0, inv)
        }
        return partialAmount;
    }
}
interface IRewardReceiver {
    function onRewardReceived(uint8 subjectType, uint256 subject, uint256 amount) external;
}
contract FortaStaking_v_010 is BaseComponentUpgradeable, ERC1155SupplyUpgradeable, SubjectTypeValidator {
    using Distributions for Distributions.Balances;
    using Distributions for Distributions.SignedBalances;
    using Timers        for Timers.Timestamp;
    using ERC165Checker for address;
    IERC20 public stakedToken;
    Distributions.Balances private _activeStake;
    Distributions.Balances private _inactiveStake;
    mapping(uint256 => mapping(address => Timers.Timestamp)) private _lockingDelay;
    Distributions.Balances private _rewards;
    mapping(uint256 => Distributions.SignedBalances) private _released;
    mapping(uint256 => bool) private _frozen;
    uint64 private _withdrawalDelay;
    address private _treasury;
    IStakeController private _stakingParameters;
    event StakeDeposited(uint8 indexed subjectType, uint256 indexed subject, address indexed account, uint256 amount);
    event WithdrawalInitiated(uint8 indexed subjectType, uint256 indexed subject, address indexed account, uint64 deadline);
    event WithdrawalExecuted(uint8 indexed subjectType, uint256 indexed subject, address indexed account);
    event Froze(uint8 indexed subjectType, uint256 indexed subject, address indexed by, bool isFrozen);
    event Slashed(uint8 indexed subjectType, uint256 indexed subject, address indexed by, uint256 value);
    event Rewarded(uint8 indexed subjectType, uint256 indexed subject, address indexed from, uint256 value);
    event Released(uint8 indexed subjectType, uint256 indexed subject, address indexed to, uint256 value);
    event DelaySet(uint256 newWithdrawalDelay);
    event TreasurySet(address newTreasury);
    event StakeParamsManagerSet(address indexed newManager);
    event MaxStakeReached(uint8 indexed subjectType, uint256 indexed subject);
    event TokensSwept(address indexed token, address to, uint256 amount);
    error WithdrawalNotReady();
    error SlashingOver90Percent();
    error WithdrawalSharesNotTransferible();
    error FrozenSubject();
    error NoActiveShares();
    error NoInactiveShares();
    error StakeInactiveOrSubjectNotFound();
    string public constant version = "0.1.0";
    constructor(address forwarder) initializer ForwardedContext(forwarder) {}
    function initialize(
        address __manager,
        address __router,
        IERC20 __stakedToken,
        uint64 __withdrawalDelay,
        address __treasury
    ) public initializer {
        if (__treasury == address(0)) revert ZeroAddress("__treasury");
        __AccessManaged_init(__manager);
        __Routed_init(__router);
        __UUPSUpgradeable_init();
        __ERC1155_init("");
        __ERC1155Supply_init();
        stakedToken = __stakedToken;
        _withdrawalDelay = __withdrawalDelay;
        _treasury = __treasury;
        emit DelaySet(__withdrawalDelay);
        emit TreasurySet(__treasury);
    }
    function activeStakeFor(uint8 subjectType, uint256 subject) public view returns (uint256) {
        return _activeStake.balanceOf(FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function totalActiveStake() public view returns (uint256) {
        return _activeStake.totalSupply();
    }
    function inactiveStakeFor(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return _inactiveStake.balanceOf(FortaStakingUtils.subjectToInactive(subjectType, subject));
    }
    function totalInactiveStake() public view returns (uint256) {
        return _inactiveStake.totalSupply();
    }
    function sharesOf(uint8 subjectType, uint256 subject, address account) public view returns (uint256) {
        return balanceOf(account, FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function totalShares(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return totalSupply(FortaStakingUtils.subjectToActive(subjectType, subject));
    }
    function inactiveSharesOf(uint8 subjectType, uint256 subject, address account) external view returns (uint256) {
        return balanceOf(account, FortaStakingUtils.subjectToInactive(subjectType, subject));
    }
    function totalInactiveShares(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return totalSupply(FortaStakingUtils.subjectToInactive(subjectType, subject));
    }
    function isFrozen(uint8 subjectType, uint256 subject) public view returns (bool) {
        return _frozen[FortaStakingUtils.subjectToActive(subjectType, subject)];
    }
    function deposit(uint8 subjectType, uint256 subject, uint256 stakeValue)
        public
        onlyValidSubjectType(subjectType)
        returns (uint256)
    {
        if (address(_stakingParameters) == address(0)) revert ZeroAddress("_stakingParameters");
        if (!_stakingParameters.isStakeActivatedFor(subjectType, subject)) revert StakeInactiveOrSubjectNotFound();
        address staker = _msgSender();
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        bool reachedMax;
        (stakeValue, reachedMax) = _getInboundStake(subjectType, subject, stakeValue);
        if (reachedMax) {
            emit MaxStakeReached(subjectType, subject);
        }
        uint256 sharesValue = _stakeToActiveShares(activeSharesId, stakeValue);
        SafeERC20.safeTransferFrom(stakedToken, staker, address(this), stakeValue);
        _activeStake.mint(activeSharesId, stakeValue);
        _mint(staker, activeSharesId, sharesValue, new bytes(0));
        emit StakeDeposited(subjectType, subject, staker, stakeValue);
        return sharesValue;
    }
    function _getInboundStake(uint8 subjectType, uint256 subject, uint256 stakeValue) private view returns (uint256, bool) {
        uint256 max = _stakingParameters.maxStakeFor(subjectType, subject);
        if (activeStakeFor(subjectType, subject) >= max) {
            return (0, true);
        } else {
            uint256 stakeLeft = max - activeStakeFor(subjectType, subject);
            return (
                Math.min(
                    stakeValue, 
                    stakeLeft 
                ),
                activeStakeFor(subjectType, subject) + stakeValue >= max
            );
        }
    }
    function initiateWithdrawal(uint8 subjectType, uint256 subject, uint256 sharesValue)
        public
        onlyValidSubjectType(subjectType)
        returns (uint64)
    {
        address staker = _msgSender();
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        if (balanceOf(staker, activeSharesId) == 0) revert NoActiveShares();
        uint64 deadline = SafeCast.toUint64(block.timestamp) + _withdrawalDelay;
        _lockingDelay[activeSharesId][staker].setDeadline(deadline);
        uint256 activeShares   = Math.min(sharesValue, balanceOf(staker, activeSharesId));
        uint256 stakeValue     = _activeSharesToStake(activeSharesId, activeShares);
        uint256 inactiveShares = _stakeToInactiveShares(FortaStakingUtils.activeToInactive(activeSharesId), stakeValue);
        _activeStake.burn(activeSharesId, stakeValue);
        _inactiveStake.mint(FortaStakingUtils.activeToInactive(activeSharesId), stakeValue);
        _burn(staker, activeSharesId, activeShares);
        _mint(staker, FortaStakingUtils.activeToInactive(activeSharesId), inactiveShares, new bytes(0));
        emit WithdrawalInitiated(subjectType, subject, staker, deadline);
        return deadline;
    }
    function withdraw(uint8 subjectType, uint256 subject)
        public
        onlyValidSubjectType(subjectType)
        returns (uint256)
    {
        address staker = _msgSender();
        uint256 inactiveSharesId = FortaStakingUtils.subjectToInactive(subjectType, subject);
        if (balanceOf(staker, inactiveSharesId) == 0) revert NoInactiveShares();
        if (_frozen[FortaStakingUtils.inactiveToActive(inactiveSharesId)]) revert FrozenSubject();
        Timers.Timestamp storage timer = _lockingDelay[FortaStakingUtils.inactiveToActive(inactiveSharesId)][staker];
        if (!timer.isExpired()) revert WithdrawalNotReady();
        timer.reset();
        emit WithdrawalExecuted(subjectType, subject, staker);
        uint256 inactiveShares = balanceOf(staker, inactiveSharesId);
        uint256 stakeValue     = _inactiveSharesToStake(inactiveSharesId, inactiveShares);
        _inactiveStake.burn(inactiveSharesId, stakeValue);
        _burn(staker, inactiveSharesId, inactiveShares);
        SafeERC20.safeTransfer(stakedToken, staker, stakeValue);
        return stakeValue;
    }
    function slash(uint8 subjectType, uint256 subject, uint256 stakeValue)
        public
        onlyRole(SLASHER_ROLE)
        onlyValidSubjectType(subjectType)
        returns (uint256)
    {
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        uint256 activeStake       = _activeStake.balanceOf(activeSharesId);
        uint256 inactiveStake     = _inactiveStake.balanceOf(FortaStakingUtils.activeToInactive(activeSharesId));
        uint256 maxSlashableStake = FullMath.mulDiv(9, 10, activeStake + inactiveStake);
        if (stakeValue > maxSlashableStake) revert SlashingOver90Percent();
        uint256 slashFromActive   = FullMath.mulDiv(activeStake, activeStake + inactiveStake, stakeValue);
        uint256 slashFromInactive = stakeValue - slashFromActive;
        stakeValue                = slashFromActive + slashFromInactive;
        _activeStake.burn(activeSharesId, slashFromActive);
        _inactiveStake.burn(FortaStakingUtils.activeToInactive(activeSharesId), slashFromInactive);
        SafeERC20.safeTransfer(stakedToken, _treasury, stakeValue);
        emit Slashed(subjectType, subject, _msgSender(), stakeValue);
        return stakeValue;
    }
    function freeze(uint8 subjectType, uint256 subject, bool frozen)
        public
        onlyRole(SLASHER_ROLE)
        onlyValidSubjectType(subjectType)
    {
        _frozen[FortaStakingUtils.subjectToActive(subjectType, subject)] = frozen;
        emit Froze(subjectType, subject, _msgSender(), frozen);
    }
    function reward(uint8 subjectType, uint256 subject, uint256 value) public onlyValidSubjectType(subjectType)  {   
        SafeERC20.safeTransferFrom(stakedToken, _msgSender(), address(this), value);
        _rewards.mint(FortaStakingUtils.subjectToActive(subjectType, subject), value);
        emit Rewarded(subjectType, subject, _msgSender(), value);
    }
    function sweep(IERC20 token, address recipient) public onlyRole(SWEEPER_ROLE) returns (uint256) {
        uint256 amount = token.balanceOf(address(this));
        if (token == stakedToken) {
            amount -= totalActiveStake();
            amount -= totalInactiveStake();
            amount -= _rewards.totalSupply();
        }
        SafeERC20.safeTransfer(token, recipient, amount);
        emit TokensSwept(address(token), recipient, amount);
        return amount;
    }
    function releaseReward(uint8 subjectType, uint256 subject, address account)
        public
        onlyValidSubjectType(subjectType)
        returns (uint256)
    {
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        uint256 value = _availableReward(activeSharesId, account);
        _rewards.burn(activeSharesId, value);
        _released[activeSharesId].mint(account, SafeCast.toInt256(value));
        SafeERC20.safeTransfer(stakedToken, account, value);
        emit Released(subjectType, subject, account, value);
        if (Address.isContract(account) && account.supportsInterface(type(IRewardReceiver).interfaceId)) {
            IRewardReceiver(account).onRewardReceived(subjectType, subject, value);
        }
        return value;
    }
    function _availableReward(uint256 activeSharesId, address account) internal view returns (uint256) {
        return SafeCast.toUint256(
            SafeCast.toInt256(_historicalRewardFraction(activeSharesId, balanceOf(account, activeSharesId)))
            -
            _released[activeSharesId].balanceOf(account)
        );
    }
    function availableReward(uint8 subjectType, uint256 subject, address account) external view returns (uint256) {
        uint256 activeSharesId = FortaStakingUtils.subjectToActive(subjectType, subject);
        return _availableReward(activeSharesId, account);
    }
    function relayPermit(
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        IERC2612(address(stakedToken)).permit(_msgSender(), address(this), value, deadline, v, r, s);
    }
    function _totalHistoricalReward(uint256 activeSharesId) internal view returns (uint256) {
        return SafeCast.toUint256(
            SafeCast.toInt256(_rewards.balanceOf(activeSharesId))
            +
            _released[activeSharesId].totalSupply()
        );
    }
    function _historicalRewardFraction(uint256 activeSharesId, uint256 amount) internal view returns (uint256) {
        uint256 supply = totalSupply(activeSharesId);
        return amount > 0 && supply > 0 ? FullMath.mulDiv(amount, supply, _totalHistoricalReward(activeSharesId)) : 0;
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        for (uint256 i = 0; i < ids.length; i++) {
            if (FortaStakingUtils.isActive(ids[i])) {
                int256 virtualRelease = SafeCast.toInt256(
                    _historicalRewardFraction(
                        ids[i],
                        amounts[i]
                    )
                );
                if (from == address(0)) {
                    _released[ids[i]].mint(to, virtualRelease);
                } else if (to == address(0)) {
                    _released[ids[i]].burn(from, virtualRelease);
                } else {
                    _released[ids[i]].transfer(from, to, virtualRelease);
                }
            } else {
                if (!(from == address(0) || to == address(0))) revert WithdrawalSharesNotTransferible();
            }
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
    function _stakeToActiveShares(uint256 activeSharesId, uint256 amount) internal view returns (uint256) {
        uint256 activeStake = _activeStake.balanceOf(activeSharesId);
        return activeStake == 0 ? amount : FullMath.mulDiv(amount, activeStake, totalSupply(activeSharesId));
    }
    function _stakeToInactiveShares(uint256 inactiveSharesId, uint256 amount) internal view returns (uint256) {
        uint256 inactiveStake = _inactiveStake.balanceOf(inactiveSharesId);
        return inactiveStake == 0 ? amount : FullMath.mulDiv(amount, inactiveStake, totalSupply(inactiveSharesId));
    }
    function _activeSharesToStake(uint256 activeSharesId, uint256 amount) internal view returns (uint256) {
        uint256 activeSupply = totalSupply(activeSharesId);
        return activeSupply == 0 ? 0 : FullMath.mulDiv(amount, activeSupply, _activeStake.balanceOf(activeSharesId));
    }
    function _inactiveSharesToStake(uint256 inactiveSharesId, uint256 amount) internal view returns (uint256) {
        uint256 inactiveSupply = totalSupply(inactiveSharesId);
        return inactiveSupply == 0 ? 0 : FullMath.mulDiv(amount, inactiveSupply, _inactiveStake.balanceOf(inactiveSharesId));
    }
    function setDelay(uint64 newDelay) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _withdrawalDelay = newDelay;
        emit DelaySet(newDelay);
    }
    function setTreasury(address newTreasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress("newTreasury");
        _treasury = newTreasury;
        emit TreasurySet(newTreasury);
    }
    function setStakingParametersManager(IStakeController newStakingParameters) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(newStakingParameters) == address(0)) revert ZeroAddress("newStakingParameters");
        emit StakeParamsManagerSet(address(newStakingParameters));
        _stakingParameters = newStakingParameters;
    }
    function setURI(string memory newUri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newUri);
    }
    function _msgSender() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[40] private __gap;
}
contract FortaStakingParameters_0_1_0 is BaseComponentUpgradeable, SubjectTypeValidator, IStakeController {
    FortaStaking_v_010 private _fortaStaking;
    mapping(uint8 => IStakeSubject) private _stakeSubjectHandlers;
    event FortaStakingChanged(address staking);
    string public constant version = "0.1.0";
    constructor(address forwarder) initializer ForwardedContext(forwarder) {}
    function initialize(
        address __manager,
        address __router,
        address __fortaStaking
    ) public initializer {
        __AccessManaged_init(__manager);
        __Routed_init(__router);
        __UUPSUpgradeable_init();
        _setFortaStaking(__fortaStaking);
    }
    function setFortaStaking(address newFortaStaking) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFortaStaking(newFortaStaking);
    }
    function _setFortaStaking(address newFortaStaking) internal {
        if (newFortaStaking== address(0)) revert ZeroAddress("newFortaStaking");
        _fortaStaking = FortaStaking_v_010(newFortaStaking);
        emit FortaStakingChanged(address(_fortaStaking));
    }
    function setStakeSubjectHandler(uint8 subjectType, IStakeSubject subjectHandler)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyValidSubjectType(subjectType)
    {
        if (address(subjectHandler) == address(0)) revert ZeroAddress("subjectHandler");
        emit StakeSubjectHandlerChanged(address(subjectHandler), address(_stakeSubjectHandlers[subjectType]));
        _stakeSubjectHandlers[subjectType] = subjectHandler;
    }
    function maxStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256) {
        return _stakeSubjectHandlers[subjectType].getStakeThreshold(subject).max;
    }
    function minStakeFor(uint8 subjectType, uint256 subject) external view returns(uint256) {
        return _stakeSubjectHandlers[subjectType].getStakeThreshold(subject).min;
    }
    function isStakeActivatedFor(uint8 subjectType, uint256 subject) external view returns(bool) {
        return _stakeSubjectHandlers[subjectType].getStakeThreshold(subject).activated;
    }
    function activeStakeFor(uint8 subjectType, uint256 subject) external view returns (uint256) {
        return _fortaStaking.activeStakeFor(subjectType, subject);
    }
}