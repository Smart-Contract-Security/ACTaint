pragma solidity ^0.7.0;
import "../interfaces/IBasePoolRelayer.sol";
contract MockBasePoolRelayer is IBasePoolRelayer {
    bool internal _hasCalledPool;
    function hasCalledPool(bytes32) external view override returns (bool) {
        return _hasCalledPool;
    }
    function mockHasCalledPool(bool _newHasCalledPool) external {
        _hasCalledPool = _newHasCalledPool;
    }
}