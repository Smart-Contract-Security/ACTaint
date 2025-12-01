pragma solidity ^0.8.0;
import "./IGovernorTimelock.sol";
import "../Governor.sol";
import "../TimelockController.sol";
abstract contract GovernorTimelockControl is IGovernorTimelock, Governor {
    TimelockController private _timelock;
    mapping(uint256 => bytes32) private _timelockIds;
    event TimelockChange(address oldTimelock, address newTimelock);
    constructor(TimelockController timelockAddress) {
        _updateTimelock(timelockAddress);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, Governor) returns (bool) {
        return interfaceId == type(IGovernorTimelock).interfaceId || super.supportsInterface(interfaceId);
    }
    function state(uint256 proposalId) public view virtual override(IGovernor, Governor) returns (ProposalState) {
        ProposalState currentState = super.state(proposalId);
        if (currentState != ProposalState.Succeeded) {
            return currentState;
        }
        bytes32 queueid = _timelockIds[proposalId];
        if (queueid == bytes32(0)) {
            return currentState;
        } else if (_timelock.isOperationDone(queueid)) {
            return ProposalState.Executed;
        } else if (_timelock.isOperationPending(queueid)) {
            return ProposalState.Queued;
        } else {
            return ProposalState.Canceled;
        }
    }
    function timelock() public view virtual override returns (address) {
        return address(_timelock);
    }
    function proposalEta(uint256 proposalId) public view virtual override returns (uint256) {
        uint256 eta = _timelock.getTimestamp(_timelockIds[proposalId]);
        return eta == 1 ? 0 : eta; 
    }
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        require(state(proposalId) == ProposalState.Succeeded, "Governor: proposal not successful");
        uint256 delay = _timelock.getMinDelay();
        _timelockIds[proposalId] = _timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        _timelock.scheduleBatch(targets, values, calldatas, 0, descriptionHash, delay);
        emit ProposalQueued(proposalId, block.timestamp + delay);
        return proposalId;
    }
    function _execute(
        uint256 ,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override {
        _timelock.executeBatch{value: msg.value}(targets, values, calldatas, 0, descriptionHash);
    }
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);
        if (_timelockIds[proposalId] != 0) {
            _timelock.cancel(_timelockIds[proposalId]);
            delete _timelockIds[proposalId];
        }
        return proposalId;
    }
    function _executor() internal view virtual override returns (address) {
        return address(_timelock);
    }
    function updateTimelock(TimelockController newTimelock) external virtual onlyGovernance {
        _updateTimelock(newTimelock);
    }
    function _updateTimelock(TimelockController newTimelock) private {
        emit TimelockChange(address(_timelock), address(newTimelock));
        _timelock = newTimelock;
    }
}