pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
contract FactoryWidePauseWindow {
    uint256 private constant _INITIAL_PAUSE_WINDOW_DURATION = 90 days;
    uint256 private constant _BUFFER_PERIOD_DURATION = 30 days;
    uint256 private immutable _poolsPauseWindowEndTime;
    constructor() {
        _poolsPauseWindowEndTime = block.timestamp + _INITIAL_PAUSE_WINDOW_DURATION;
    }
    function getPauseConfiguration() public view returns (uint256 pauseWindowDuration, uint256 bufferPeriodDuration) {
        uint256 currentTime = block.timestamp;
        if (currentTime < _poolsPauseWindowEndTime) {
            pauseWindowDuration = _poolsPauseWindowEndTime - currentTime; 
            bufferPeriodDuration = _BUFFER_PERIOD_DURATION;
        } else {
            pauseWindowDuration = 0;
            bufferPeriodDuration = 0;
        }
    }
}