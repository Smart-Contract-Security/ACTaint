pragma solidity ^0.7.0;
import "../helpers/TemporarilyPausable.sol";
contract TemporarilyPausableMock is TemporarilyPausable {
    constructor(uint256 pauseWindowDuration, uint256 bufferPeriodDuration)
        TemporarilyPausable(pauseWindowDuration, bufferPeriodDuration)
    {}
    function setPaused(bool paused) external {
        _setPaused(paused);
    }
}