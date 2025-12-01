pragma solidity ^0.8.0;
import "../../utils/introspection/IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";
contract SupportsInterfaceWithLookupMockUpgradeable is Initializable, IERC165Upgradeable {
    bytes4 public constant INTERFACE_ID_ERC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) private _supportedInterfaces;
    function __SupportsInterfaceWithLookupMock_init() internal onlyInitializing {
        __SupportsInterfaceWithLookupMock_init_unchained();
    }
    function __SupportsInterfaceWithLookupMock_init_unchained() internal onlyInitializing {
        _registerInterface(INTERFACE_ID_ERC165);
    }
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal {
        require(interfaceId != 0xffffffff, "ERC165InterfacesSupported: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
    uint256[49] private __gap;
}
contract ERC165InterfacesSupportedUpgradeable is Initializable, SupportsInterfaceWithLookupMockUpgradeable {
    function __ERC165InterfacesSupported_init(bytes4[] memory interfaceIds) internal onlyInitializing {
        __SupportsInterfaceWithLookupMock_init_unchained();
        __ERC165InterfacesSupported_init_unchained(interfaceIds);
    }
    function __ERC165InterfacesSupported_init_unchained(bytes4[] memory interfaceIds) internal onlyInitializing {
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            _registerInterface(interfaceIds[i]);
        }
    }
    uint256[50] private __gap;
}