pragma solidity ^0.7.0;
import "./BalancerErrors.sol";
import "./ITemporarilyPausable.sol";
abstract contract TemporarilyPausable is ITemporarilyPausable {
    uint256 private constant _MAX_PAUSE_WINDOW_DURATION = 90 days;
    uint256 private constant _MAX_BUFFER_PERIOD_DURATION = 30 days;
    uint256 private immutable _pauseWindowEndTime;
    uint256 private immutable _bufferPeriodEndTime;
    bool private _paused;
    constructor(uint256 pauseWindowDuration, uint256 bufferPeriodDuration) {
        _require(pauseWindowDuration <= _MAX_PAUSE_WINDOW_DURATION, Errors.MAX_PAUSE_WINDOW_DURATION);
        _require(bufferPeriodDuration <= _MAX_BUFFER_PERIOD_DURATION, Errors.MAX_BUFFER_PERIOD_DURATION);
        uint256 pauseWindowEndTime = block.timestamp + pauseWindowDuration;
        _pauseWindowEndTime = pauseWindowEndTime;
        _bufferPeriodEndTime = pauseWindowEndTime + bufferPeriodDuration;
    }
    modifier whenNotPaused() {
        _ensureNotPaused();
        _;
    }
    function getPausedState()
        external
        view
        override
        returns (
            bool paused,
            uint256 pauseWindowEndTime,
            uint256 bufferPeriodEndTime
        )
    {
        paused = !_isNotPaused();
        pauseWindowEndTime = _getPauseWindowEndTime();
        bufferPeriodEndTime = _getBufferPeriodEndTime();
    }
    function _setPaused(bool paused) internal {
        if (paused) {
            _require(block.timestamp < _getPauseWindowEndTime(), Errors.PAUSE_WINDOW_EXPIRED);
        } else {
            _require(block.timestamp < _getBufferPeriodEndTime(), Errors.BUFFER_PERIOD_EXPIRED);
        }
        _paused = paused;
        emit PausedStateChanged(paused);
    }
    function _ensureNotPaused() internal view {
        _require(_isNotPaused(), Errors.PAUSED);
    }
    function _isNotPaused() internal view returns (bool) {
        return block.timestamp > _getBufferPeriodEndTime() || !_paused;
    }
    function _getPauseWindowEndTime() private view returns (uint256) {
        return _pauseWindowEndTime;
    }
    function _getBufferPeriodEndTime() private view returns (uint256) {
        return _bufferPeriodEndTime;
    }
}