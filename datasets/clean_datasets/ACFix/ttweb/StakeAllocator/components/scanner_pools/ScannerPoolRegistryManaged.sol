pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ScannerPoolRegistryCore.sol";
abstract contract ScannerPoolRegistryManaged is ScannerPoolRegistryCore {
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(uint256 => EnumerableSet.AddressSet) private _managers;
    event ManagerEnabled(uint256 indexed scannerPoolId, address indexed manager, bool enabled);
    error SenderNotManager(address sender, uint256 scannerPoolId);
    modifier onlyManagerOf(uint256 scannerPoolId) {
        if (!isManager(scannerPoolId, _msgSender())) revert SenderNotManager(_msgSender(), scannerPoolId);
        _;
    }
    function isManager(uint256 scannerPoolId, address manager) public view returns (bool) {
        return _managers[scannerPoolId].contains(manager);
    }
    function getManagerCount(uint256 scannerPoolId) public view virtual returns (uint256) {
        return _managers[scannerPoolId].length();
    }
    function getManagerAt(uint256 scannerPoolId, uint256 index) public view virtual returns (address) {
        return _managers[scannerPoolId].at(index);
    }
    function setManager(uint256 scannerPoolId, address manager, bool enable) public onlyScannerPool(scannerPoolId) {
        if (enable) {
            _managers[scannerPoolId].add(manager);
        } else {
            _managers[scannerPoolId].remove(manager);
        }
        emit ManagerEnabled(scannerPoolId, manager, enable);
    }
    function _canSetEnableState(address scanner) internal virtual override view returns (bool) {
        return super._canSetEnableState(scanner) || isManager(_scannerNodes[scanner].scannerPoolId, _msgSender());
    }
    uint256[49] private __gap;
}