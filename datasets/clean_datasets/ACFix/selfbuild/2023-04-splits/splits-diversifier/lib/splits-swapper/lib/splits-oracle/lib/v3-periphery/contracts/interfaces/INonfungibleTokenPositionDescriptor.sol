pragma solidity >=0.5.0;
import './INonfungiblePositionManager.sol';
interface INonfungibleTokenPositionDescriptor {
    function tokenURI(INonfungiblePositionManager positionManager, uint256 tokenId)
        external
        view
        returns (string memory);
}