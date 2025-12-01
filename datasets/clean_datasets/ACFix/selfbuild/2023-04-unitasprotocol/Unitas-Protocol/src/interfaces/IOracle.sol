pragma solidity ^0.8.19;
interface IOracle{
    function getPrice(address) external view returns (uint64, uint64, uint256, uint256);
    function decimals() external pure returns (uint8);
    function getLatestPrice(address asset) external view returns (uint256 price);
    struct Price{
        address asset;
        uint64 timestamp;
        uint64 prev_timestamp;
        uint256 price;
        uint256 prev_price;
    }
    struct NewPrice{
        address asset;
        uint64 timestamp;
        uint256 price;
    }
}