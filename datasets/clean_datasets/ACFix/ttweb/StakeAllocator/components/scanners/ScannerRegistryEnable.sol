pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "./ScannerRegistryManaged.sol";
abstract contract ScannerRegistryEnable is ScannerRegistryManaged {
    using BitMaps for BitMaps.BitMap;
    enum Permission {
        ADMIN,
        SELF,
        OWNER,
        MANAGER,
        length
    }
    mapping(uint256 => BitMaps.BitMap) internal _disabled;
    event ScannerEnabled(uint256 indexed scannerId, bool indexed enabled, Permission permission, bool value);
    function isEnabled(uint256 scannerId) public view virtual returns (bool) {
        return isRegistered(scannerId) &&
            _getDisableFlags(scannerId) == 0 &&
            _isStakedOverMin(scannerId); 
    }
    function enableScanner(uint256 scannerId, Permission permission) public virtual {
        if (!_hasPermission(scannerId, permission)) revert DoesNotHavePermission(_msgSender(), uint8(permission), scannerId);
        _enable(scannerId, permission, true);
    }
    function disableScanner(uint256 scannerId, Permission permission) public virtual {
        if (!_hasPermission(scannerId, permission)) revert DoesNotHavePermission(_msgSender(), uint8(permission), scannerId);
        _enable(scannerId, permission, false);
    }
    function _getDisableFlags(uint256 scannerId) internal view returns (uint256) {
        return _disabled[scannerId]._data[0];
    }
    function _hasPermission(uint256 scannerId, Permission permission) internal view returns (bool) {
        if (permission == Permission.ADMIN)   { return hasRole(SCANNER_ADMIN_ROLE, _msgSender()); }
        if (permission == Permission.SELF)    { return uint256(uint160(_msgSender())) == scannerId; }
        if (permission == Permission.OWNER)   { return _msgSender() == ownerOf(scannerId); }
        if (permission == Permission.MANAGER) { return isManager(scannerId, _msgSender()); }
        return false;
    }
    function _enable(uint256 scannerId, Permission permission, bool enable) internal {
        if (!isRegistered(scannerId)) revert ScannerNotRegistered(address(uint160(scannerId)));
        _disabled[scannerId].setTo(uint8(permission), !enable);
        emit ScannerEnabled(scannerId, isEnabled(scannerId), permission, enable);
    }
    function _msgSender() internal view virtual override(ScannerRegistryCore) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ScannerRegistryCore) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[49] private __gap;
}