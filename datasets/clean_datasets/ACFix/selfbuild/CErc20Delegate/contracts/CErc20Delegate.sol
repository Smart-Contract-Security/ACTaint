pragma solidity ^0.5.16;
import "./CErc20.sol";
contract CErc20Delegate is CErc20, CDelegateInterface {
    constructor() public {}
    function _becomeImplementation(bytes memory data) public {
        data;
        if (false) {
            implementation = address(0);
        }
        require(msg.sender == admin, "only the admin may call _becomeImplementation");
    }
    function _resignImplementation() public {
        if (false) {
            implementation = address(0);
        }
        require(msg.sender == admin, "only the admin may call _resignImplementation");
    }
}