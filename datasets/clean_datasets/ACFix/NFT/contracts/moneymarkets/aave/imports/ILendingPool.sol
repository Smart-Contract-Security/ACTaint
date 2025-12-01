pragma solidity 0.5.17;
interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
    function getReserveNormalizedIncome(address asset)
        external
        view
        returns (uint256);
}