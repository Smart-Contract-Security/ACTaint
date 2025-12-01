pragma solidity 0.5.17;
interface IComptroller {
    function claimComp(address holder) external;
    function getCompAddress() external view returns (address);
}