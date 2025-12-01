pragma solidity ^0.8.0;
import "./UUPSUpgradeableMockUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
contract UUPSUpgradeableLegacyMockUpgradeable is Initializable, UUPSUpgradeableMockUpgradeable {
    function __UUPSUpgradeableLegacyMock_init() internal onlyInitializing {
    }
    function __UUPSUpgradeableLegacyMock_init_unchained() internal onlyInitializing {
    }
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;
    function __setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }
    function _upgradeToAndCallSecureLegacyV1(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        address oldImplementation = _getImplementation();
        __setImplementation(newImplementation);
        if (data.length > 0 || forceCall) {
            __functionDelegateCall(newImplementation, data);
        }
        StorageSlotUpgradeable.BooleanSlot storage rollbackTesting = StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT);
        if (!rollbackTesting.value) {
            rollbackTesting.value = true;
            __functionDelegateCall(
                newImplementation,
                abi.encodeWithSignature("upgradeTo(address)", oldImplementation)
            );
            rollbackTesting.value = false;
            require(oldImplementation == _getImplementation(), "ERC1967Upgrade: upgrade breaks further upgrades");
            _upgradeTo(newImplementation);
        }
    }
    function upgradeTo(address newImplementation) external override {
        _upgradeToAndCallSecureLegacyV1(newImplementation, bytes(""), false);
    }
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable override {
        _upgradeToAndCallSecureLegacyV1(newImplementation, data, false);
    }
    function __functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }
    uint256[50] private __gap;
}