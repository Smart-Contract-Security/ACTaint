pragma solidity ^0.8.0;
import "./IERC20Upgradeable.sol";
import "./IERC165Upgradeable.sol";
interface IERC1363Upgradeable is IERC165Upgradeable, IERC20Upgradeable {
    function transferAndCall(address to, uint256 value) external returns (bool);
    function transferAndCall(
        address to,
        uint256 value,
        bytes memory data
    ) external returns (bool);
    function transferFromAndCall(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    function transferFromAndCall(
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) external returns (bool);
    function approveAndCall(address spender, uint256 value) external returns (bool);
    function approveAndCall(
        address spender,
        uint256 value,
        bytes memory data
    ) external returns (bool);
}