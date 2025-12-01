pragma solidity 0.8.9;
interface IPriceChainLink {
    function getAssetPrice() external view returns (uint256);
}