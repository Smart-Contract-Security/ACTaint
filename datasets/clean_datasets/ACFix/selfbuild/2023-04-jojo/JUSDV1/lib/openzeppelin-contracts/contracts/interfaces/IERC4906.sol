pragma solidity ^0.8.0;
import "./IERC165.sol";
import "./IERC721.sol";
interface IERC4906 is IERC165, IERC721 {
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}