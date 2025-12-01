pragma solidity ^0.5.2;
interface ERC721MandatoryTokenReceiver {
    function onERC721BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        bytes calldata data
    ) external returns (bytes4); 
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4); 
}