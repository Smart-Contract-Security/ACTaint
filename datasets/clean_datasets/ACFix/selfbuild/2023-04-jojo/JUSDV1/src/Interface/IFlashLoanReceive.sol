pragma solidity 0.8.9;
interface IFlashLoanReceive {
    function JOJOFlashLoan(address asset, uint256 amount, address to, bytes calldata param) external;
}