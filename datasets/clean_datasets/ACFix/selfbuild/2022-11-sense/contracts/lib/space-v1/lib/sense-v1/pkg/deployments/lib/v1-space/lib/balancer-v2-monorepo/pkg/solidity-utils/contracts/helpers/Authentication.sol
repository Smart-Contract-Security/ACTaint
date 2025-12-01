pragma solidity ^0.7.0;
import "./BalancerErrors.sol";
import "./IAuthentication.sol";
abstract contract Authentication is IAuthentication {
    bytes32 private immutable _actionIdDisambiguator;
    constructor(bytes32 actionIdDisambiguator) {
        _actionIdDisambiguator = actionIdDisambiguator;
    }
    modifier authenticate() {
        _authenticateCaller();
        _;
    }
    function _authenticateCaller() internal view {
        bytes32 actionId = getActionId(msg.sig);
        _require(_canPerform(actionId, msg.sender), Errors.SENDER_NOT_ALLOWED);
    }
    function getActionId(bytes4 selector) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(_actionIdDisambiguator, selector));
    }
    function _canPerform(bytes32 actionId, address user) internal view virtual returns (bool);
}