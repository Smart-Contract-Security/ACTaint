pragma solidity ^0.8.0;
import "./ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract ERC165StorageUpgradeable is Initializable, ERC165Upgradeable {
    function __ERC165Storage_init() internal onlyInitializing {
    }
    function __ERC165Storage_init_unchained() internal onlyInitializing {
    }
    mapping(bytes4 => bool) private _supportedInterfaces;
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || _supportedInterfaces[interfaceId];
    }
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
    uint256[49] private __gap;
}