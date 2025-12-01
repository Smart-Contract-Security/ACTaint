pragma solidity ^0.7.0;
interface ITemporarilyPausable {
    event PausedStateChanged(bool paused);
    function getPausedState()
        external
        view
        returns (
            bool paused,
            uint256 pauseWindowEndTime,
            uint256 bufferPeriodEndTime
        );
}