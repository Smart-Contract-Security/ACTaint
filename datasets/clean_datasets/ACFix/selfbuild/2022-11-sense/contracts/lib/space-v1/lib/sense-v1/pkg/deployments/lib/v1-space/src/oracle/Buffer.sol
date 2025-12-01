pragma solidity ^0.7.0;
library Buffer {
    uint256 internal constant SIZE = 20;
    function prev(uint256 index) internal pure returns (uint256) {
        return sub(index, 1);
    }
    function next(uint256 index) internal pure returns (uint256) {
        return add(index, 1);
    }
    function add(uint256 index, uint256 offset) internal pure returns (uint256) {
        return (index + offset) % SIZE;
    }
    function sub(uint256 index, uint256 offset) internal pure returns (uint256) {
        return (index + SIZE - offset) % SIZE;
    }
}