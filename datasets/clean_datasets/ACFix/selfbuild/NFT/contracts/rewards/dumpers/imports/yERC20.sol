pragma solidity 0.5.17;
interface yERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function getPricePerFullShare() external view returns (uint256);
}