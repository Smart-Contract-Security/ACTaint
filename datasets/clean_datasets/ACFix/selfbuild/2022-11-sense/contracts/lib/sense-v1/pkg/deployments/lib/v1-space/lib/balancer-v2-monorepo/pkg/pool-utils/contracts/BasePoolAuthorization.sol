pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/Authentication.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IAuthorizer.sol";
import "./BasePool.sol";
abstract contract BasePoolAuthorization is Authentication {
    address private immutable _owner;
    address private constant _DELEGATE_OWNER = 0xBA1BA1ba1BA1bA1bA1Ba1BA1ba1BA1bA1ba1ba1B;
    constructor(address owner) {
        _owner = owner;
    }
    function getOwner() public view returns (address) {
        return _owner;
    }
    function getAuthorizer() external view returns (IAuthorizer) {
        return _getAuthorizer();
    }
    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        if ((getOwner() != _DELEGATE_OWNER) && _isOwnerOnlyAction(actionId)) {
            return msg.sender == getOwner();
        } else {
            return _getAuthorizer().canPerform(actionId, account, address(this));
        }
    }
    function _isOwnerOnlyAction(bytes32 actionId) internal view virtual returns (bool);
    function _getAuthorizer() internal view virtual returns (IAuthorizer);
}