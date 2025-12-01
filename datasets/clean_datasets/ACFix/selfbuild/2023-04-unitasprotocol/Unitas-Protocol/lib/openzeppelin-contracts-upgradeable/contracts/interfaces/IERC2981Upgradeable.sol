pragma solidity ^0.8.0;
import "../utils/introspection/IERC165Upgradeable.sol";
interface IERC2981Upgradeable is IERC165Upgradeable {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}