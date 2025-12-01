pragma solidity ^0.8.0;
import "../ERC721.sol";
import "../../common/ERC2981.sol";
import "../../../utils/introspection/ERC165.sol";
abstract contract ERC721Royalty is ERC2981, ERC721 {
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }
}