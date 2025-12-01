pragma solidity ^0.8.9;
interface IStakeMigrator {
    function migrate(
        uint8 oldSubjectType,
        uint256 oldSubject,
        uint8 newSubjectType,
        uint256 newSubject,
        address staker
    ) external;
}