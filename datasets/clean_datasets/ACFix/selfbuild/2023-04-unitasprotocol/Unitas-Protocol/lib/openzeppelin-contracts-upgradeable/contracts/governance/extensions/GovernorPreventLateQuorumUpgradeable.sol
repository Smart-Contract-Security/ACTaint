pragma solidity ^0.8.0;
import "../GovernorUpgradeable.sol";
import "../../utils/math/MathUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract GovernorPreventLateQuorumUpgradeable is Initializable, GovernorUpgradeable {
    using SafeCastUpgradeable for uint256;
    using TimersUpgradeable for TimersUpgradeable.BlockNumber;
    uint64 private _voteExtension;
    mapping(uint256 => TimersUpgradeable.BlockNumber) private _extendedDeadlines;
    event ProposalExtended(uint256 indexed proposalId, uint64 extendedDeadline);
    event LateQuorumVoteExtensionSet(uint64 oldVoteExtension, uint64 newVoteExtension);
    function __GovernorPreventLateQuorum_init(uint64 initialVoteExtension) internal onlyInitializing {
        __GovernorPreventLateQuorum_init_unchained(initialVoteExtension);
    }
    function __GovernorPreventLateQuorum_init_unchained(uint64 initialVoteExtension) internal onlyInitializing {
        _setLateQuorumVoteExtension(initialVoteExtension);
    }
    function proposalDeadline(uint256 proposalId) public view virtual override returns (uint256) {
        return MathUpgradeable.max(super.proposalDeadline(proposalId), _extendedDeadlines[proposalId].getDeadline());
    }
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal virtual override returns (uint256) {
        uint256 result = super._castVote(proposalId, account, support, reason, params);
        TimersUpgradeable.BlockNumber storage extendedDeadline = _extendedDeadlines[proposalId];
        if (extendedDeadline.isUnset() && _quorumReached(proposalId)) {
            uint64 extendedDeadlineValue = block.number.toUint64() + lateQuorumVoteExtension();
            if (extendedDeadlineValue > proposalDeadline(proposalId)) {
                emit ProposalExtended(proposalId, extendedDeadlineValue);
            }
            extendedDeadline.setDeadline(extendedDeadlineValue);
        }
        return result;
    }
    function lateQuorumVoteExtension() public view virtual returns (uint64) {
        return _voteExtension;
    }
    function setLateQuorumVoteExtension(uint64 newVoteExtension) public virtual onlyGovernance {
        _setLateQuorumVoteExtension(newVoteExtension);
    }
    function _setLateQuorumVoteExtension(uint64 newVoteExtension) internal virtual {
        emit LateQuorumVoteExtensionSet(_voteExtension, newVoteExtension);
        _voteExtension = newVoteExtension;
    }
    uint256[48] private __gap;
}