pragma solidity ^0.8.0;
import "./IERC1820ImplementerUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
contract ERC1820ImplementerUpgradeable is Initializable, IERC1820ImplementerUpgradeable {
    function __ERC1820Implementer_init() internal onlyInitializing {
    }
    function __ERC1820Implementer_init_unchained() internal onlyInitializing {
    }
    bytes32 private constant _ERC1820_ACCEPT_MAGIC = keccak256("ERC1820_ACCEPT_MAGIC");
    mapping(bytes32 => mapping(address => bool)) private _supportedInterfaces;
    function canImplementInterfaceForAddress(bytes32 interfaceHash, address account)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return _supportedInterfaces[interfaceHash][account] ? _ERC1820_ACCEPT_MAGIC : bytes32(0x00);
    }
    function _registerInterfaceForAddress(bytes32 interfaceHash, address account) internal virtual {
        _supportedInterfaces[interfaceHash][account] = true;
    }
    uint256[49] private __gap;
}