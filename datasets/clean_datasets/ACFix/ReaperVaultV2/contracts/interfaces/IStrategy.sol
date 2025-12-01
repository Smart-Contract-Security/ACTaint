pragma solidity ^0.8.0;
interface IStrategy {
    function withdraw(uint256 _amount) external returns (uint256 loss);
    function harvest() external returns (uint256 callerFee);
    function balanceOf() external view returns (uint256);
    function vault() external view returns (address);
    function want() external view returns (address);
}