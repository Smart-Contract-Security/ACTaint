pragma solidity >=0.7.5;
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
interface IERC721Permit is IERC721 {
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}