pragma solidity ^0.8.0;
import "../ERC721.sol";
import "../../../governance/utils/Votes.sol";
abstract contract ERC721Votes is ERC721, Votes {
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _transferVotingUnits(from, to, 1);
        super._afterTokenTransfer(from, to, tokenId);
    }
    function _afterConsecutiveTokenTransfer(
        address from,
        address to,
        uint256 first,
        uint96 size
    ) internal virtual override {
        _transferVotingUnits(from, to, size);
        super._afterConsecutiveTokenTransfer(from, to, first, size);
    }
    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }
}