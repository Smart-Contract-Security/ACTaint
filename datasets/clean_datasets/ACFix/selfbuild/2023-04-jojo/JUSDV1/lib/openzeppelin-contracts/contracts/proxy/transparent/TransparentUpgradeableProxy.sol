pragma solidity ^0.8.0;
import "../ERC1967/ERC1967Proxy.sol";
interface ITransparentUpgradeableProxy is IERC1967 {
    function admin() external view returns (address);
    function implementation() external view returns (address);
    function changeAdmin(address) external;
    function upgradeTo(address) external;
    function upgradeToAndCall(address, bytes memory) external payable;
}
contract TransparentUpgradeableProxy is ERC1967Proxy {
    constructor(address _logic, address admin_, bytes memory _data) payable ERC1967Proxy(_logic, _data) {
        _changeAdmin(admin_);
    }
    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }
    function _fallback() internal virtual override {
        if (msg.sender == _getAdmin()) {
            bytes memory ret;
            bytes4 selector = msg.sig;
            if (selector == ITransparentUpgradeableProxy.upgradeTo.selector) {
                ret = _dispatchUpgradeTo();
            } else if (selector == ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
                ret = _dispatchUpgradeToAndCall();
            } else if (selector == ITransparentUpgradeableProxy.changeAdmin.selector) {
                ret = _dispatchChangeAdmin();
            } else if (selector == ITransparentUpgradeableProxy.admin.selector) {
                ret = _dispatchAdmin();
            } else if (selector == ITransparentUpgradeableProxy.implementation.selector) {
                ret = _dispatchImplementation();
            } else {
                revert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
            }
            assembly {
                return(add(ret, 0x20), mload(ret))
            }
        } else {
            super._fallback();
        }
    }
    function _dispatchAdmin() private returns (bytes memory) {
        _requireZeroValue();
        address admin = _getAdmin();
        return abi.encode(admin);
    }
    function _dispatchImplementation() private returns (bytes memory) {
        _requireZeroValue();
        address implementation = _implementation();
        return abi.encode(implementation);
    }
    function _dispatchChangeAdmin() private returns (bytes memory) {
        _requireZeroValue();
        address newAdmin = abi.decode(msg.data[4:], (address));
        _changeAdmin(newAdmin);
        return "";
    }
    function _dispatchUpgradeTo() private returns (bytes memory) {
        _requireZeroValue();
        address newImplementation = abi.decode(msg.data[4:], (address));
        _upgradeToAndCall(newImplementation, bytes(""), false);
        return "";
    }
    function _dispatchUpgradeToAndCall() private returns (bytes memory) {
        (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
        _upgradeToAndCall(newImplementation, data, true);
        return "";
    }
    function _admin() internal view virtual returns (address) {
        return _getAdmin();
    }
    function _requireZeroValue() private {
        require(msg.value == 0);
    }
}