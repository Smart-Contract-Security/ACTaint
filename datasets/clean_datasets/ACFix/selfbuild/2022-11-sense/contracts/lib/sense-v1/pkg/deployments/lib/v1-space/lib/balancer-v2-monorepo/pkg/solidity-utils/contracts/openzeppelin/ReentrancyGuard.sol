pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    constructor() {
        _status = _NOT_ENTERED;
    }
    modifier nonReentrant() {
        _enterNonReentrant();
        _;
        _exitNonReentrant();
    }
    function _enterNonReentrant() private {
        _require(_status != _ENTERED, Errors.REENTRANCY);
        _status = _ENTERED;
    }
    function _exitNonReentrant() private {
        _status = _NOT_ENTERED;
    }
}