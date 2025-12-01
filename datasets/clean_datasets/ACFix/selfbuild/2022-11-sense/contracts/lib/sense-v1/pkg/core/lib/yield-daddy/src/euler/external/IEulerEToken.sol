pragma solidity ^0.8.13;
interface IEulerEToken {
    function balanceOfUnderlying(address account) external view returns (uint256);
    function deposit(uint256 subAccountId, uint256 amount) external;
    function withdraw(uint256 subAccountId, uint256 amount) external;
}