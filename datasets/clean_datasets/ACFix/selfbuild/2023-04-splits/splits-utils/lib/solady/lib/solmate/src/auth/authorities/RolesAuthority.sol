pragma solidity >=0.8.0;
import {Auth, Authority} from "../Auth.sol";
contract RolesAuthority is Auth, Authority {
    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);
    event PublicCapabilityUpdated(address indexed target, bytes4 indexed functionSig, bool enabled);
    event RoleCapabilityUpdated(uint8 indexed role, address indexed target, bytes4 indexed functionSig, bool enabled);
    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}
    mapping(address => bytes32) public getUserRoles;
    mapping(address => mapping(bytes4 => bool)) public isCapabilityPublic;
    mapping(address => mapping(bytes4 => bytes32)) public getRolesWithCapability;
    function doesUserHaveRole(address user, uint8 role) public view virtual returns (bool) {
        return (uint256(getUserRoles[user]) >> role) & 1 != 0;
    }
    function doesRoleHaveCapability(
        uint8 role,
        address target,
        bytes4 functionSig
    ) public view virtual returns (bool) {
        return (uint256(getRolesWithCapability[target][functionSig]) >> role) & 1 != 0;
    }
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) public view virtual override returns (bool) {
        return
            isCapabilityPublic[target][functionSig] ||
            bytes32(0) != getUserRoles[user] & getRolesWithCapability[target][functionSig];
    }
    function setPublicCapability(
        address target,
        bytes4 functionSig,
        bool enabled
    ) public virtual requiresAuth {
        isCapabilityPublic[target][functionSig] = enabled;
        emit PublicCapabilityUpdated(target, functionSig, enabled);
    }
    function setRoleCapability(
        uint8 role,
        address target,
        bytes4 functionSig,
        bool enabled
    ) public virtual requiresAuth {
        if (enabled) {
            getRolesWithCapability[target][functionSig] |= bytes32(1 << role);
        } else {
            getRolesWithCapability[target][functionSig] &= ~bytes32(1 << role);
        }
        emit RoleCapabilityUpdated(role, target, functionSig, enabled);
    }
    function setUserRole(
        address user,
        uint8 role,
        bool enabled
    ) public virtual requiresAuth {
        if (enabled) {
            getUserRoles[user] |= bytes32(1 << role);
        } else {
            getUserRoles[user] &= ~bytes32(1 << role);
        }
        emit UserRoleUpdated(user, role, enabled);
    }
}