pragma solidity ^0.8.0;
import "../ERC721.sol";
import "../../../interfaces/IERC2309.sol";
import "../../../utils/Checkpoints.sol";
import "../../../utils/structs/BitMaps.sol";
abstract contract ERC721Consecutive is IERC2309, ERC721 {
    using BitMaps for BitMaps.BitMap;
    using Checkpoints for Checkpoints.Trace160;
    Checkpoints.Trace160 private _sequentialOwnership;
    BitMaps.BitMap private _sequentialBurn;
    function _maxBatchSize() internal view virtual returns (uint96) {
        return 5000;
    }
    function _ownerOf(uint256 tokenId) internal view virtual override returns (address) {
        address owner = super._ownerOf(tokenId);
        if (owner != address(0) || tokenId > type(uint96).max) {
            return owner;
        }
        return _sequentialBurn.get(tokenId) ? address(0) : address(_sequentialOwnership.lowerLookup(uint96(tokenId)));
    }
    function _mintConsecutive(address to, uint96 batchSize) internal virtual returns (uint96) {
        uint96 first = _totalConsecutiveSupply();
        if (batchSize > 0) {
            require(!Address.isContract(address(this)), "ERC721Consecutive: batch minting restricted to constructor");
            require(to != address(0), "ERC721Consecutive: mint to the zero address");
            require(batchSize <= _maxBatchSize(), "ERC721Consecutive: batch too large");
            _beforeTokenTransfer(address(0), to, first, batchSize);
            uint96 last = first + batchSize - 1;
            _sequentialOwnership.push(last, uint160(to));
            __unsafe_increaseBalance(to, batchSize);
            emit ConsecutiveTransfer(first, last, address(0), to);
            _afterTokenTransfer(address(0), to, first, batchSize);
        }
        return first;
    }
    function _mint(address to, uint256 tokenId) internal virtual override {
        require(Address.isContract(address(this)), "ERC721Consecutive: can't mint during construction");
        super._mint(to, tokenId);
    }
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        if (
            to == address(0) && 
            firstTokenId < _totalConsecutiveSupply() && 
            !_sequentialBurn.get(firstTokenId) 
        ) {
            require(batchSize == 1, "ERC721Consecutive: batch burn not supported");
            _sequentialBurn.set(firstTokenId);
        }
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }
    function _totalConsecutiveSupply() private view returns (uint96) {
        (bool exists, uint96 latestId, ) = _sequentialOwnership.latestCheckpoint();
        return exists ? latestId + 1 : 0;
    }
}