pragma solidity ^0.8.9;
import "./IStakeSubject.sol";
interface IDirectStakeSubject is IStakeSubject {
    function getStakeThreshold(uint256 subject) external view returns (StakeThreshold memory);
    function isStakedOverMin(uint256 subject) external view returns (bool);
}