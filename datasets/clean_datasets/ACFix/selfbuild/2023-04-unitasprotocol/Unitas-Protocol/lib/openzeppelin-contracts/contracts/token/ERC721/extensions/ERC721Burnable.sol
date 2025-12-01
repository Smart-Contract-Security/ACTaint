pragma solidity ^0.8.0;
import "../ERC721.sol";
import "../../../utils/Context.sol";
abstract contract ERC721Burnable is Context, ERC721 {
    function burn(uint256 tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
    }
}