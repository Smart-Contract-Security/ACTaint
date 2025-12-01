pragma solidity ^0.7.0;
import "./interfaces/IAuthorizer.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/AccessControl.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
contract Authorizer is AccessControl, IAuthorizer {
    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }
    function canPerform(
        bytes32 actionId,
        address account,
        address
    ) public view override returns (bool) {
        return AccessControl.hasRole(actionId, account);
    }
    function grantRoles(bytes32[] memory roles, address account) external {
        for (uint256 i = 0; i < roles.length; i++) {
            grantRole(roles[i], account);
        }
    }
    function grantRolesToMany(bytes32[] memory roles, address[] memory accounts) external {
        InputHelpers.ensureInputLengthMatch(roles.length, accounts.length);
        for (uint256 i = 0; i < roles.length; i++) {
            grantRole(roles[i], accounts[i]);
        }
    }
    function revokeRoles(bytes32[] memory roles, address account) external {
        for (uint256 i = 0; i < roles.length; i++) {
            revokeRole(roles[i], account);
        }
    }
    function revokeRolesFromMany(bytes32[] memory roles, address[] memory accounts) external {
        InputHelpers.ensureInputLengthMatch(roles.length, accounts.length);
        for (uint256 i = 0; i < roles.length; i++) {
            revokeRole(roles[i], accounts[i]);
        }
    }
}