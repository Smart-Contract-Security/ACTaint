pragma solidity ^0.8.17;
import {OwnableImpl} from "./OwnableImpl.sol";
abstract contract PausableImpl is OwnableImpl {
    error Paused();
    event SetPaused(bool paused);
    bool internal $paused;
    constructor() {}
    function __initPausable(address owner_, bool paused_) internal virtual {
        OwnableImpl.__initOwnable(owner_);
        $paused = paused_;
    }
    modifier pausable() virtual {
        if (paused()) revert Paused();
        _;
    }
    function setPaused(bool paused_) public virtual onlyOwner {
        $paused = paused_;
        emit SetPaused(paused_);
    }
    function paused() public view virtual returns (bool) {
        return $paused;
    }
}