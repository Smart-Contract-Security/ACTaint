pragma solidity ^0.8.0;
import "./TransparentUpgradeableProxy.sol";
import "../../access/Ownable.sol";
contract ProxyAdmin is Ownable {
    function getProxyImplementation(ITransparentUpgradeableProxy proxy) public view virtual returns (address) {
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b");
        require(success);
        return abi.decode(returndata, (address));
    }
    function getProxyAdmin(ITransparentUpgradeableProxy proxy) public view virtual returns (address) {
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440");
        require(success);
        return abi.decode(returndata, (address));
    }
    function changeProxyAdmin(ITransparentUpgradeableProxy proxy, address newAdmin) public virtual onlyOwner {
        proxy.changeAdmin(newAdmin);
    }
    function upgrade(ITransparentUpgradeableProxy proxy, address implementation) public virtual onlyOwner {
        proxy.upgradeTo(implementation);
    }
    function upgradeAndCall(
        ITransparentUpgradeableProxy proxy,
        address implementation,
        bytes memory data
    ) public payable virtual onlyOwner {
        proxy.upgradeToAndCall{value: msg.value}(implementation, data);
    }
}