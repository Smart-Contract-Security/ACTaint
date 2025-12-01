pragma solidity 0.8.9;
interface IMarkPriceSource {
    function getMarkPrice() external view returns (uint256 price);
}