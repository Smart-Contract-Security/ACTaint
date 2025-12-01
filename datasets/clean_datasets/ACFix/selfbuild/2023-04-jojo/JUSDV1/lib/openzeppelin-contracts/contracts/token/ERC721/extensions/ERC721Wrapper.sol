pragma solidity ^0.8.0;
import "../ERC721.sol";
abstract contract ERC721Wrapper is ERC721, IERC721Receiver {
    IERC721 private immutable _underlying;
    constructor(IERC721 underlyingToken) {
        _underlying = underlyingToken;
    }
    function depositFor(address account, uint256[] memory tokenIds) public virtual returns (bool) {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenId = tokenIds[i];
            underlying().transferFrom(_msgSender(), address(this), tokenId);
            _safeMint(account, tokenId);
        }
        return true;
    }
    function withdrawTo(address account, uint256[] memory tokenIds) public virtual returns (bool) {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenId = tokenIds[i];
            require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Wrapper: caller is not token owner or approved");
            _burn(tokenId);
            underlying().safeTransferFrom(address(this), account, tokenId);
        }
        return true;
    }
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes memory
    ) public virtual override returns (bytes4) {
        require(address(underlying()) == _msgSender(), "ERC721Wrapper: caller is not underlying");
        _safeMint(from, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
    function _recover(address account, uint256 tokenId) internal virtual returns (uint256) {
        require(underlying().ownerOf(tokenId) == address(this), "ERC721Wrapper: wrapper is not token owner");
        _safeMint(account, tokenId);
        return tokenId;
    }
    function underlying() public view virtual returns (IERC721) {
        return _underlying;
    }
}