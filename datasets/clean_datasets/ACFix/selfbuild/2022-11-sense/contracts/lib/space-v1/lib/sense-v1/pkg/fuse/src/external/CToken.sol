pragma solidity 0.8.11;
interface CToken {
    function underlying() external view returns (address);
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function decimals() external view returns (uint8);
}