pragma solidity ^0.8.0;
import "../ERC721Upgradeable.sol";
import "../../common/ERC2981Upgradeable.sol";
import "../../../utils/introspection/ERC165Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC721RoyaltyUpgradeable is Initializable, ERC2981Upgradeable, ERC721Upgradeable {
    function __ERC721Royalty_init() internal onlyInitializing {
    }
    function __ERC721Royalty_init_unchained() internal onlyInitializing {
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, ERC2981Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }
    uint256[50] private __gap;
}