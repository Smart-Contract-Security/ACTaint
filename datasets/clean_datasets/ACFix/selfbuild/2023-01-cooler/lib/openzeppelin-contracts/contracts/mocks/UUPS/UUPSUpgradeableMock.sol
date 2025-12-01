pragma solidity ^0.8.0;
import "../CountersImpl.sol";
import "../../proxy/utils/UUPSUpgradeable.sol";
contract UUPSUpgradeableMock is CountersImpl, UUPSUpgradeable {
    function _authorizeUpgrade(address) internal virtual override {}
}
contract UUPSUpgradeableUnsafeMock is UUPSUpgradeableMock {
    function upgradeTo(address newImplementation) external virtual override {
        ERC1967Upgrade._upgradeToAndCall(newImplementation, bytes(""), false);
    }
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual override {
        ERC1967Upgrade._upgradeToAndCall(newImplementation, data, false);
    }
}