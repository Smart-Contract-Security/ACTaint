pragma solidity 0.5.17;
interface IMoneyMarket {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amountInUnderlying)
        external
        returns (uint256 actualAmountWithdrawn);
    function claimRewards() external; 
    function totalValue() external returns (uint256); 
    function incomeIndex() external returns (uint256); 
    function stablecoin() external view returns (address);
    function setRewards(address newValue) external;
    event ESetParamAddress(
        address indexed sender,
        string indexed paramName,
        address newValue
    );
}