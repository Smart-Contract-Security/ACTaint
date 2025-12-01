pragma solidity ^0.8.0;
interface IERC1822ProxiableUpgradeable {
    function proxiableUUID() external view returns (bytes32);
}