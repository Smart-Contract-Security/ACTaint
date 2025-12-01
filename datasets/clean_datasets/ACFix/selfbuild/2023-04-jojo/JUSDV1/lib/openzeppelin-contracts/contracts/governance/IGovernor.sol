pragma solidity ^0.8.0;
import "../interfaces/IERC165.sol";
import "../interfaces/IERC6372.sol";
abstract contract IGovernor is IERC165, IERC6372 {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event VoteCastWithParams(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 weight,
        string reason,
        bytes params
    );
    function name() public view virtual returns (string memory);
    function version() public view virtual returns (string memory);
    function clock() public view virtual override returns (uint48);
    function CLOCK_MODE() public view virtual override returns (string memory);
    function COUNTING_MODE() public view virtual returns (string memory);
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256);
    function state(uint256 proposalId) public view virtual returns (ProposalState);
    function proposalSnapshot(uint256 proposalId) public view virtual returns (uint256);
    function proposalDeadline(uint256 proposalId) public view virtual returns (uint256);
    function proposalProposer(uint256 proposalId) public view virtual returns (address);
    function votingDelay() public view virtual returns (uint256);
    function votingPeriod() public view virtual returns (uint256);
    function quorum(uint256 timepoint) public view virtual returns (uint256);
    function getVotes(address account, uint256 timepoint) public view virtual returns (uint256);
    function getVotesWithParams(
        address account,
        uint256 timepoint,
        bytes memory params
    ) public view virtual returns (uint256);
    function hasVoted(uint256 proposalId, address account) public view virtual returns (bool);
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256 proposalId);
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable virtual returns (uint256 proposalId);
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256 proposalId);
    function castVote(uint256 proposalId, uint8 support) public virtual returns (uint256 balance);
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) public virtual returns (uint256 balance);
    function castVoteWithReasonAndParams(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params
    ) public virtual returns (uint256 balance);
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual returns (uint256 balance);
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        bytes memory params,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual returns (uint256 balance);
}