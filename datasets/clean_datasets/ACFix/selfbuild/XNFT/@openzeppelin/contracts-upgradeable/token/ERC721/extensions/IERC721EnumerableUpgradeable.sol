pragma solidity ^0.8.0;
import "../IERC721Upgradeable.sol";
interface IERC721EnumerableUpgradeable is IERC721Upgradeable {
    function totalSupply() external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
}