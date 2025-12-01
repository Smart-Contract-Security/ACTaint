pragma solidity ^0.8.0;
import "../ERC1967/ERC1967Proxy.sol";
contract TransparentUpgradeableProxy is ERC1967Proxy {
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable ERC1967Proxy(_logic, _data) {
        _changeAdmin(admin_);
    }
    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }
    function admin() external ifAdmin returns (address admin_) {
        admin_ = _getAdmin();
    }
    function implementation() external ifAdmin returns (address implementation_) {
        implementation_ = _implementation();
    }
    function changeAdmin(address newAdmin) external virtual ifAdmin {
        _changeAdmin(newAdmin);
    }
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeToAndCall(newImplementation, bytes(""), false);
    }
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _upgradeToAndCall(newImplementation, data, true);
    }
    function _admin() internal view virtual returns (address) {
        return _getAdmin();
    }
    function _beforeFallback() internal virtual override {
        require(msg.sender != _getAdmin(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        super._beforeFallback();
    }
}