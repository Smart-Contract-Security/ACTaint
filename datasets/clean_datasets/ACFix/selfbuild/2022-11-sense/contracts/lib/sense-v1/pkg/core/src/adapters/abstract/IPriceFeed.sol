pragma solidity 0.8.13;
interface IPriceFeed {
    function price(address underlying) external view returns (uint256 price);
}