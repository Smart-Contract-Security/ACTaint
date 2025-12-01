pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "./AgentRegistryCore.sol";
abstract contract AgentRegistryEnable is AgentRegistryCore {
    using BitMaps for BitMaps.BitMap;
    enum Permission {
        ADMIN,
        OWNER,
        length
    }
    mapping(uint256 => BitMaps.BitMap) private _disabled;
    event AgentEnabled(uint256 indexed agentId, bool indexed enabled, Permission permission, bool value);
    function isEnabled(uint256 agentId) public view virtual returns (bool) {
        return (
            isRegistered(agentId) &&
            getDisableFlags(agentId) == 0 &&
            (!_isStakeActivated() || _isStakedOverMin(agentId))
        );
    }
    function enableAgent(uint256 agentId, Permission permission) public virtual {
        if (!_hasPermission(agentId, permission)) revert DoesNotHavePermission(_msgSender(), uint8(permission), agentId);
        _enable(agentId, permission, true);
    }
    function disableAgent(uint256 agentId, Permission permission) public virtual {
        if (!_hasPermission(agentId, permission)) revert DoesNotHavePermission(_msgSender(), uint8(permission), agentId);
        _enable(agentId, permission, false);
    }
    function getDisableFlags(uint256 agentId) public view returns (uint256) {
        return _disabled[agentId]._data[0];
    }
    function _hasPermission(uint256 agentId, Permission permission) internal view returns (bool) {
        if (permission == Permission.ADMIN) { return hasRole(AGENT_ADMIN_ROLE, _msgSender()); }
        if (permission == Permission.OWNER) { return _msgSender() == ownerOf(agentId); }
        return false;
    }
    function _enable(uint256 agentId, Permission permission, bool enable) internal {
        _beforeAgentEnable(agentId, permission, enable);
        _agentEnable(agentId, permission, enable);
        _afterAgentEnable(agentId, permission, enable);
    }
    function _beforeAgentEnable(uint256 agentId, Permission permission, bool value) internal virtual {
    }
    function _agentEnable(uint256 agentId, Permission permission, bool value) internal virtual {
        _disabled[agentId].setTo(uint8(permission), !value);
        emit AgentEnabled(agentId, isEnabled(agentId), permission, value);
    }
    function _afterAgentEnable(uint256 agentId, Permission permission, bool value) internal virtual {
    }
    function _msgSender() internal view virtual override(AgentRegistryCore) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(AgentRegistryCore) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[49] private __gap;
}