pragma solidity >=0.8.0;
import {Auth, Authority} from "../Auth.sol";
contract MultiRolesAuthority is Auth, Authority {
    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);
    event PublicCapabilityUpdated(bytes4 indexed functionSig, bool enabled);
    event RoleCapabilityUpdated(uint8 indexed role, bytes4 indexed functionSig, bool enabled);
    event TargetCustomAuthorityUpdated(address indexed target, Authority indexed authority);
    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}
    mapping(address => Authority) public getTargetCustomAuthority;
    mapping(address => bytes32) public getUserRoles;
    mapping(bytes4 => bool) public isCapabilityPublic;
    mapping(bytes4 => bytes32) public getRolesWithCapability;
    function doesUserHaveRole(address user, uint8 role) public view virtual returns (bool) {
        return (uint256(getUserRoles[user]) >> role) & 1 != 0;
    }
    function doesRoleHaveCapability(uint8 role, bytes4 functionSig) public view virtual returns (bool) {
        return (uint256(getRolesWithCapability[functionSig]) >> role) & 1 != 0;
    }
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) public view virtual override returns (bool) {
        Authority customAuthority = getTargetCustomAuthority[target];
        if (address(customAuthority) != address(0)) return customAuthority.canCall(user, target, functionSig);
        return
            isCapabilityPublic[functionSig] || bytes32(0) != getUserRoles[user] & getRolesWithCapability[functionSig];
    }
    function setTargetCustomAuthority(address target, Authority customAuthority) public virtual requiresAuth {
        getTargetCustomAuthority[target] = customAuthority;
        emit TargetCustomAuthorityUpdated(target, customAuthority);
    }
    function setPublicCapability(bytes4 functionSig, bool enabled) public virtual requiresAuth {
        isCapabilityPublic[functionSig] = enabled;
        emit PublicCapabilityUpdated(functionSig, enabled);
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
    function setRoleCapability(
        uint8 role,
        bytes4 functionSig,
        bool enabled
    ) public virtual requiresAuth {
        if (enabled) {
            getRolesWithCapability[functionSig] |= bytes32(1 << role);
        } else {
            getRolesWithCapability[functionSig] &= ~bytes32(1 << role);
        }
        emit RoleCapabilityUpdated(role, functionSig, enabled);
    }
}