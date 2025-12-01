pragma solidity ^0.8.0;
import "./AccessControl.sol";
import "./IAccessControlDefaultAdminRules.sol";
import "../utils/math/SafeCast.sol";
import "../interfaces/IERC5313.sol";
abstract contract AccessControlDefaultAdminRules is IAccessControlDefaultAdminRules, IERC5313, AccessControl {
    address private _pendingDefaultAdmin;
    uint48 private _pendingDefaultAdminSchedule; 
    uint48 private _currentDelay;
    address private _currentDefaultAdmin;
    uint48 private _pendingDelay;
    uint48 private _pendingDelaySchedule; 
    constructor(uint48 initialDelay, address initialDefaultAdmin) {
        _currentDelay = initialDelay;
        _grantRole(DEFAULT_ADMIN_ROLE, initialDefaultAdmin);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlDefaultAdminRules).interfaceId || super.supportsInterface(interfaceId);
    }
    function owner() public view virtual returns (address) {
        return defaultAdmin();
    }
    function grantRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        require(role != DEFAULT_ADMIN_ROLE, "AccessControl: can't directly grant default admin role");
        super.grantRole(role, account);
    }
    function revokeRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        require(role != DEFAULT_ADMIN_ROLE, "AccessControl: can't directly revoke default admin role");
        super.revokeRole(role, account);
    }
    function renounceRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        if (role == DEFAULT_ADMIN_ROLE) {
            (address newDefaultAdmin, uint48 schedule) = pendingDefaultAdmin();
            require(
                newDefaultAdmin == address(0) && _isScheduleSet(schedule) && _hasSchedulePassed(schedule),
                "AccessControl: only can renounce in two delayed steps"
            );
        }
        super.renounceRole(role, account);
    }
    function _grantRole(bytes32 role, address account) internal virtual override {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(defaultAdmin() == address(0), "AccessControl: default admin already granted");
            _currentDefaultAdmin = account;
        }
        super._grantRole(role, account);
    }
    function _revokeRole(bytes32 role, address account) internal virtual override {
        if (role == DEFAULT_ADMIN_ROLE) {
            delete _currentDefaultAdmin;
        }
        super._revokeRole(role, account);
    }
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual override {
        require(role != DEFAULT_ADMIN_ROLE, "AccessControl: can't violate default admin rules");
        super._setRoleAdmin(role, adminRole);
    }
    function defaultAdmin() public view virtual returns (address) {
        return _currentDefaultAdmin;
    }
    function pendingDefaultAdmin() public view virtual returns (address newAdmin, uint48 schedule) {
        return (_pendingDefaultAdmin, _pendingDefaultAdminSchedule);
    }
    function defaultAdminDelay() public view virtual returns (uint48) {
        uint48 schedule = _pendingDelaySchedule;
        return (_isScheduleSet(schedule) && _hasSchedulePassed(schedule)) ? _pendingDelay : _currentDelay;
    }
    function pendingDefaultAdminDelay() public view virtual returns (uint48 newDelay, uint48 schedule) {
        schedule = _pendingDelaySchedule;
        return (_isScheduleSet(schedule) && !_hasSchedulePassed(schedule)) ? (_pendingDelay, schedule) : (0, 0);
    }
    function defaultAdminDelayIncreaseWait() public view virtual returns (uint48) {
        return 5 days;
    }
    function beginDefaultAdminTransfer(address newAdmin) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _beginDefaultAdminTransfer(newAdmin);
    }
    function _beginDefaultAdminTransfer(address newAdmin) internal virtual {
        uint48 newSchedule = SafeCast.toUint48(block.timestamp) + defaultAdminDelay();
        _setPendingDefaultAdmin(newAdmin, newSchedule);
        emit DefaultAdminTransferScheduled(newAdmin, newSchedule);
    }
    function cancelDefaultAdminTransfer() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _cancelDefaultAdminTransfer();
    }
    function _cancelDefaultAdminTransfer() internal virtual {
        _setPendingDefaultAdmin(address(0), 0);
    }
    function acceptDefaultAdminTransfer() public virtual {
        (address newDefaultAdmin, ) = pendingDefaultAdmin();
        require(_msgSender() == newDefaultAdmin, "AccessControl: pending admin must accept");
        _acceptDefaultAdminTransfer();
    }
    function _acceptDefaultAdminTransfer() internal virtual {
        (address newAdmin, uint48 schedule) = pendingDefaultAdmin();
        require(_isScheduleSet(schedule) && _hasSchedulePassed(schedule), "AccessControl: transfer delay not passed");
        _revokeRole(DEFAULT_ADMIN_ROLE, defaultAdmin());
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        delete _pendingDefaultAdmin;
        delete _pendingDefaultAdminSchedule;
    }
    function changeDefaultAdminDelay(uint48 newDelay) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _changeDefaultAdminDelay(newDelay);
    }
    function _changeDefaultAdminDelay(uint48 newDelay) internal virtual {
        uint48 newSchedule = SafeCast.toUint48(block.timestamp) + _delayChangeWait(newDelay);
        _setPendingDelay(newDelay, newSchedule);
        emit DefaultAdminDelayChangeScheduled(newDelay, newSchedule);
    }
    function rollbackDefaultAdminDelay() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _rollbackDefaultAdminDelay();
    }
    function _rollbackDefaultAdminDelay() internal virtual {
        _setPendingDelay(0, 0);
    }
    function _delayChangeWait(uint48 newDelay) internal view virtual returns (uint48) {
        uint48 currentDelay = defaultAdminDelay();
        return
            newDelay > currentDelay
                ? uint48(Math.min(newDelay, defaultAdminDelayIncreaseWait())) 
                : currentDelay - newDelay;
    }
    function _setPendingDefaultAdmin(address newAdmin, uint48 newSchedule) private {
        (, uint48 oldSchedule) = pendingDefaultAdmin();
        _pendingDefaultAdmin = newAdmin;
        _pendingDefaultAdminSchedule = newSchedule;
        if (_isScheduleSet(oldSchedule)) {
            emit DefaultAdminTransferCanceled();
        }
    }
    function _setPendingDelay(uint48 newDelay, uint48 newSchedule) private {
        uint48 oldSchedule = _pendingDelaySchedule;
        if (_isScheduleSet(oldSchedule)) {
            if (_hasSchedulePassed(oldSchedule)) {
                _currentDelay = _pendingDelay;
            } else {
                emit DefaultAdminDelayChangeCanceled();
            }
        }
        _pendingDelay = newDelay;
        _pendingDelaySchedule = newSchedule;
    }
    function _isScheduleSet(uint48 schedule) private pure returns (bool) {
        return schedule != 0;
    }
    function _hasSchedulePassed(uint48 schedule) private view returns (bool) {
        return schedule < block.timestamp;
    }
}