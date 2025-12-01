pragma solidity ^0.8.0;
import "../ERC721.sol";
import "../../../security/Pausable.sol";
abstract contract ERC721Pausable is ERC721, Pausable {
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        require(!paused(), "ERC721Pausable: token transfer while paused");
    }
}