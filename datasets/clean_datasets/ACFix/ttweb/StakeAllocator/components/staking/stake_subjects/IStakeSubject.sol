pragma solidity ^0.8.9;
interface IStakeSubject {
    struct StakeThreshold {
        uint256 min;
        uint256 max;
        bool activated;
    }
    error StakeThresholdMaxLessOrEqualMin();
    function isRegistered(uint256 subject) external view returns(bool);
    function ownerOf(uint256 subject) external view returns (address);
}