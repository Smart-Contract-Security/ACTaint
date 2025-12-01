pragma solidity ^0.8.0;
import "./IGovernorTimelock.sol";
import "../Governor.sol";
import "../../utils/math/SafeCast.sol";
import "../../vendor/compound/ICompoundTimelock.sol";
abstract contract GovernorTimelockCompound is IGovernorTimelock, Governor {
    using SafeCast for uint256;
    using Timers for Timers.Timestamp;
    struct ProposalTimelock {
        Timers.Timestamp timer;
    }
    ICompoundTimelock private _timelock;
    mapping(uint256 => ProposalTimelock) private _proposalTimelocks;
    event TimelockChange(address oldTimelock, address newTimelock);
    constructor(ICompoundTimelock timelockAddress) {
        _updateTimelock(timelockAddress);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, Governor) returns (bool) {
        return interfaceId == type(IGovernorTimelock).interfaceId || super.supportsInterface(interfaceId);
    }
    function state(uint256 proposalId) public view virtual override(IGovernor, Governor) returns (ProposalState) {
        ProposalState status = super.state(proposalId);
        if (status != ProposalState.Succeeded) {
            return status;
        }
        uint256 eta = proposalEta(proposalId);
        if (eta == 0) {
            return status;
        } else if (block.timestamp >= eta + _timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }
    function timelock() public view virtual override returns (address) {
        return address(_timelock);
    }
    function proposalEta(uint256 proposalId) public view virtual override returns (uint256) {
        return _proposalTimelocks[proposalId].timer.getDeadline();
    }
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        require(state(proposalId) == ProposalState.Succeeded, "Governor: proposal not successful");
        uint256 eta = block.timestamp + _timelock.delay();
        _proposalTimelocks[proposalId].timer.setDeadline(eta.toUint64());
        for (uint256 i = 0; i < targets.length; ++i) {
            require(
                !_timelock.queuedTransactions(keccak256(abi.encode(targets[i], values[i], "", calldatas[i], eta))),
                "GovernorTimelockCompound: identical proposal action already queued"
            );
            _timelock.queueTransaction(targets[i], values[i], "", calldatas[i], eta);
        }
        emit ProposalQueued(proposalId, eta);
        return proposalId;
    }
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 
    ) internal virtual override {
        uint256 eta = proposalEta(proposalId);
        require(eta > 0, "GovernorTimelockCompound: proposal not yet queued");
        Address.sendValue(payable(_timelock), msg.value);
        for (uint256 i = 0; i < targets.length; ++i) {
            _timelock.executeTransaction(targets[i], values[i], "", calldatas[i], eta);
        }
    }
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override returns (uint256) {
        uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);
        uint256 eta = proposalEta(proposalId);
        if (eta > 0) {
            for (uint256 i = 0; i < targets.length; ++i) {
                _timelock.cancelTransaction(targets[i], values[i], "", calldatas[i], eta);
            }
            _proposalTimelocks[proposalId].timer.reset();
        }
        return proposalId;
    }
    function _executor() internal view virtual override returns (address) {
        return address(_timelock);
    }
    function __acceptAdmin() public {
        _timelock.acceptAdmin();
    }
    function updateTimelock(ICompoundTimelock newTimelock) external virtual onlyGovernance {
        _updateTimelock(newTimelock);
    }
    function _updateTimelock(ICompoundTimelock newTimelock) private {
        emit TimelockChange(address(_timelock), address(newTimelock));
        _timelock = newTimelock;
    }
}