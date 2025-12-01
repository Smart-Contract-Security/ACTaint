pragma solidity >=0.5.0;
interface IPeripheryImmutableState {
    function factory() external view returns (address);
    function WETH9() external view returns (address);
}