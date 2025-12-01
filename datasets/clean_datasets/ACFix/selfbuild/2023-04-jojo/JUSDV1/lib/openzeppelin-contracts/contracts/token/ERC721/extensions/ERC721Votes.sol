pragma solidity ^0.8.0;
import "../ERC721.sol";
import "../../../governance/utils/Votes.sol";
abstract contract ERC721Votes is ERC721, Votes {
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        _transferVotingUnits(from, to, batchSize);
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }
    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }
}