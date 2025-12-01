pragma solidity ^0.8.4;
import "./AccessControl.sol";
import "../crosschain/CrossChainEnabled.sol";
abstract contract AccessControlCrossChain is AccessControl, CrossChainEnabled {
    bytes32 public constant CROSSCHAIN_ALIAS = keccak256("CROSSCHAIN_ALIAS");
    function _checkRole(bytes32 role) internal view virtual override {
        if (_isCrossChain()) {
            _checkRole(_crossChainRoleAlias(role), _crossChainSender());
        } else {
            super._checkRole(role);
        }
    }
    function _crossChainRoleAlias(bytes32 role) internal pure virtual returns (bytes32) {
        return role ^ CROSSCHAIN_ALIAS;
    }
}