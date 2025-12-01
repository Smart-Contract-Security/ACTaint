pragma solidity ^0.5.16;
contract InterestRateModel {
    bool public constant isInterestRateModel = true;
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint);
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint);
}