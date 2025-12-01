pragma solidity ^0.8.9;
import "../BaseComponentUpgradeable.sol";
import "./AgentRegistryCore.sol";
import "./AgentRegistryEnable.sol";
import "./AgentRegistryEnumerable.sol";
import "./AgentRegistryMetadata.sol";
contract AgentRegistry is
    BaseComponentUpgradeable,
    AgentRegistryCore,
    AgentRegistryEnable,
    AgentRegistryMetadata,
    AgentRegistryEnumerable
{
    string public constant version = "0.1.6";
    constructor(address forwarder) initializer ForwardedContext(forwarder) {}
    function initialize(
        address __manager,
        string calldata __name,
        string calldata __symbol
    ) public initializer {
        __BaseComponentUpgradeable_init(__manager);
        __ERC721_init(__name, __symbol);
    }
    function getAgentState(uint256 agentId)
        public view
        returns (
            bool registered,
            address owner,
            uint256 agentVersion,
            string memory metadata,
            uint256[] memory chainIds,
            bool enabled,
            uint256 disabledFlags
        ) {
        (registered, owner, agentVersion, metadata, chainIds) = getAgent(agentId);
        return (
            registered,
            owner,
            agentVersion,
            metadata,
            chainIds,
            isEnabled(agentId),
            getDisableFlags(agentId)
        );
    }
    function _beforeAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual override(AgentRegistryCore, AgentRegistryEnumerable) {
        super._beforeAgentUpdate(agentId, newMetadata, newChainIds);
    }
    function _agentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual override(AgentRegistryCore, AgentRegistryMetadata) {
        super._agentUpdate(agentId, newMetadata, newChainIds);
    }
    function _msgSender() internal view virtual override(BaseComponentUpgradeable, AgentRegistryCore, AgentRegistryEnable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(BaseComponentUpgradeable, AgentRegistryCore, AgentRegistryEnable) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[50] private __gap;
}