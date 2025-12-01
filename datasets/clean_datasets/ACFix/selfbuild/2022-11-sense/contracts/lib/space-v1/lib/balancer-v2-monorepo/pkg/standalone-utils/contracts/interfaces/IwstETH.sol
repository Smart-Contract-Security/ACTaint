pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
interface IwstETH {
    function stETH() external returns (IERC20);
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
    function stEthPerToken() external view returns (uint256);
    function tokensPerStEth() external view returns (uint256);
}