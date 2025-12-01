pragma solidity ^0.8.17;
import "src/core/IOracle.sol";
contract ZeroOracle is IOracle {
    function getPrice(address) external view returns (uint price) {}
}