pragma solidity ^0.8.9;
interface IVersioned {
    function version() external returns(string memory v);
}