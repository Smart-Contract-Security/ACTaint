pragma solidity ^0.8.0;
import "./GovernorVotesUpgradeable.sol";
import "../../utils/CheckpointsUpgradeable.sol";
import "../../utils/math/SafeCastUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract GovernorVotesQuorumFractionUpgradeable is Initializable, GovernorVotesUpgradeable {
    using CheckpointsUpgradeable for CheckpointsUpgradeable.History;
    uint256 private _quorumNumerator; 
    CheckpointsUpgradeable.History private _quorumNumeratorHistory;
    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);
    function __GovernorVotesQuorumFraction_init(uint256 quorumNumeratorValue) internal onlyInitializing {
        __GovernorVotesQuorumFraction_init_unchained(quorumNumeratorValue);
    }
    function __GovernorVotesQuorumFraction_init_unchained(uint256 quorumNumeratorValue) internal onlyInitializing {
        _updateQuorumNumerator(quorumNumeratorValue);
    }
    function quorumNumerator() public view virtual returns (uint256) {
        return _quorumNumeratorHistory._checkpoints.length == 0 ? _quorumNumerator : _quorumNumeratorHistory.latest();
    }
    function quorumNumerator(uint256 blockNumber) public view virtual returns (uint256) {
        uint256 length = _quorumNumeratorHistory._checkpoints.length;
        if (length == 0) {
            return _quorumNumerator;
        }
        CheckpointsUpgradeable.Checkpoint memory latest = _quorumNumeratorHistory._checkpoints[length - 1];
        if (latest._blockNumber <= blockNumber) {
            return latest._value;
        }
        return _quorumNumeratorHistory.getAtBlock(blockNumber);
    }
    function quorumDenominator() public view virtual returns (uint256) {
        return 100;
    }
    function quorum(uint256 blockNumber) public view virtual override returns (uint256) {
        return (token.getPastTotalSupply(blockNumber) * quorumNumerator(blockNumber)) / quorumDenominator();
    }
    function updateQuorumNumerator(uint256 newQuorumNumerator) external virtual onlyGovernance {
        _updateQuorumNumerator(newQuorumNumerator);
    }
    function _updateQuorumNumerator(uint256 newQuorumNumerator) internal virtual {
        require(
            newQuorumNumerator <= quorumDenominator(),
            "GovernorVotesQuorumFraction: quorumNumerator over quorumDenominator"
        );
        uint256 oldQuorumNumerator = quorumNumerator();
        if (oldQuorumNumerator != 0 && _quorumNumeratorHistory._checkpoints.length == 0) {
            _quorumNumeratorHistory._checkpoints.push(
                CheckpointsUpgradeable.Checkpoint({_blockNumber: 0, _value: SafeCastUpgradeable.toUint224(oldQuorumNumerator)})
            );
        }
        _quorumNumeratorHistory.push(newQuorumNumerator);
        emit QuorumNumeratorUpdated(oldQuorumNumerator, newQuorumNumerator);
    }
    uint256[48] private __gap;
}