pragma solidity ^0.8.0;
import "../IERC721ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
contract ERC721HolderUpgradeable is Initializable, IERC721ReceiverUpgradeable {
    function __ERC721Holder_init() internal onlyInitializing {
    }
    function __ERC721Holder_init_unchained() internal onlyInitializing {
    }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    uint256[50] private __gap;
}