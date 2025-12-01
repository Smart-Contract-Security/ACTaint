pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../BaseComponentUpgradeable.sol";
import "../staking/stake_subjects/DirectStakeSubject.sol";
import "../../tools/FrontRunningProtection.sol";
import "../../errors/GeneralErrors.sol";
abstract contract AgentRegistryCore is
    BaseComponentUpgradeable,
    FrontRunningProtection,
    ERC721Upgradeable,
    DirectStakeSubjectUpgradeable
{
    StakeThreshold private _stakeThreshold; 
    uint256 public frontRunningDelay;
    event AgentCommitted(bytes32 indexed commit);
    event AgentUpdated(uint256 indexed agentId, address indexed by, string metadata, uint256[] chainIds);
    event StakeThresholdChanged(uint256 min, uint256 max, bool activated);
    event FrontRunningDelaySet(uint256 delay);
    modifier onlyOwnerOf(uint256 agentId) {
        if (_msgSender() != ownerOf(agentId)) revert SenderNotOwner(_msgSender(), agentId);
        _;
    }
    modifier onlySorted(uint256[] memory array) {
        if (array.length == 0 ) revert EmptyArray("chainIds");
        for (uint256 i = 1; i < array.length; i++ ) {
            if (array[i] <= array[i-1]) revert UnorderedArray("chainIds");
        }
        _;
    }
    function prepareAgent(bytes32 commit) public {
        _frontrunCommit(commit);
    }
    function createAgent(uint256 agentId, address owner, string calldata metadata, uint256[] calldata chainIds)
    public
        onlySorted(chainIds)
        frontrunProtected(keccak256(abi.encodePacked(agentId, owner, metadata, chainIds)), frontRunningDelay)
    {
        _mint(owner, agentId);
        _beforeAgentUpdate(agentId, metadata, chainIds);
        _agentUpdate(agentId, metadata, chainIds);
        _afterAgentUpdate(agentId, metadata, chainIds);
    }
    function isRegistered(uint256 agentId) public view returns(bool) {
        return _exists(agentId);
    }
    function updateAgent(uint256 agentId, string calldata metadata, uint256[] calldata chainIds)
    public
        onlyOwnerOf(agentId)
        onlySorted(chainIds)
    {
        _beforeAgentUpdate(agentId, metadata, chainIds);
        _agentUpdate(agentId, metadata, chainIds);
        _afterAgentUpdate(agentId, metadata, chainIds);
    }
    function setStakeThreshold(StakeThreshold memory newStakeThreshold) external onlyRole(AGENT_ADMIN_ROLE) {
        if (newStakeThreshold.max <= newStakeThreshold.min) revert StakeThresholdMaxLessOrEqualMin();
        _stakeThreshold = newStakeThreshold;
        emit StakeThresholdChanged(newStakeThreshold.min, newStakeThreshold.max, newStakeThreshold.activated);
    }
    function getStakeThreshold(uint256 ) public override view returns (StakeThreshold memory) {
        return _stakeThreshold;
    }
    function _isStakeActivated() internal view returns(bool) {
        return address(getSubjectHandler()) != address(0) && _stakeThreshold.activated;
    }
    function _isStakedOverMin(uint256 subject) internal override view returns(bool) {
        return getSubjectHandler().activeStakeFor(AGENT_SUBJECT, subject) >= _stakeThreshold.min && _exists(subject);
    }
    function setFrontRunningDelay(uint256 delay) external onlyRole(AGENT_ADMIN_ROLE) {
        frontRunningDelay = delay;
        emit FrontRunningDelaySet(delay);
    }
    function _beforeAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual {
    }
    function _agentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual {
        emit AgentUpdated(agentId, _msgSender(), newMetadata, newChainIds);
    }
    function _afterAgentUpdate(uint256 agentId, string memory newMetadata, uint256[] calldata newChainIds) internal virtual {
    }
    function _msgSender() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ContextUpgradeable, BaseComponentUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }
    function ownerOf(uint256 subject) public view virtual override(DirectStakeSubjectUpgradeable, ERC721Upgradeable) returns (address) {
        return super.ownerOf(subject);
    }
    uint256[41] private __gap; 
}