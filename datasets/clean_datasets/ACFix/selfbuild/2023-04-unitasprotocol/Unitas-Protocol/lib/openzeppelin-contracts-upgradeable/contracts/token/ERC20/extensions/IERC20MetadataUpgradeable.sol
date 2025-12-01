pragma solidity ^0.8.0;
import "../IERC20Upgradeable.sol";
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}