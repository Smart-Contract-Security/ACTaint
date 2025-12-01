pragma solidity ^0.8.0;
import "../../utils/math/SafeCast.sol";
import "../extensions/IGovernorTimelock.sol";
import "../Governor.sol";
import "./IGovernorCompatibilityBravo.sol";
abstract contract GovernorCompatibilityBravo is IGovernorTimelock, IGovernorCompatibilityBravo, Governor {
    enum VoteType {
        Against,
        For,
        Abstain
    }
    struct ProposalDetails {
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => Receipt) receipts;
        bytes32 descriptionHash;
    }
    mapping(uint256 => ProposalDetails) private _proposalDetails;
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=bravo";
    }
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override(IGovernor, Governor) returns (uint256) {
        _storeProposal(_msgSender(), targets, values, new string[](calldatas.length), calldatas, description);
        return super.propose(targets, values, calldatas, description);
    }
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        require(signatures.length == calldatas.length, "GovernorBravo: invalid signatures length");
        _storeProposal(_msgSender(), targets, values, signatures, calldatas, description);
        return propose(targets, values, _encodeCalldata(signatures, calldatas), description);
    }
    function queue(uint256 proposalId) public virtual override {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = _getProposalParameters(proposalId);
        queue(targets, values, calldatas, descriptionHash);
    }
    function execute(uint256 proposalId) public payable virtual override {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = _getProposalParameters(proposalId);
        execute(targets, values, calldatas, descriptionHash);
    }
    function cancel(uint256 proposalId) public virtual override {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = _getProposalParameters(proposalId);
        cancel(targets, values, calldatas, descriptionHash);
    }
    function cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual override(IGovernor, Governor) returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
        address proposer = _proposalDetails[proposalId].proposer;
        require(
            _msgSender() == proposer || getVotes(proposer, clock() - 1) < proposalThreshold(),
            "GovernorBravo: proposer above threshold"
        );
        return _cancel(targets, values, calldatas, descriptionHash);
    }
    function _encodeCalldata(
        string[] memory signatures,
        bytes[] memory calldatas
    ) private pure returns (bytes[] memory) {
        bytes[] memory fullcalldatas = new bytes[](calldatas.length);
        for (uint256 i = 0; i < fullcalldatas.length; ++i) {
            fullcalldatas[i] = bytes(signatures[i]).length == 0
                ? calldatas[i]
                : abi.encodePacked(bytes4(keccak256(bytes(signatures[i]))), calldatas[i]);
        }
        return fullcalldatas;
    }
    function _getProposalParameters(
        uint256 proposalId
    )
        private
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    {
        ProposalDetails storage details = _proposalDetails[proposalId];
        return (
            details.targets,
            details.values,
            _encodeCalldata(details.signatures, details.calldatas),
            details.descriptionHash
        );
    }
    function _storeProposal(
        address proposer,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) private {
        bytes32 descriptionHash = keccak256(bytes(description));
        uint256 proposalId = hashProposal(targets, values, _encodeCalldata(signatures, calldatas), descriptionHash);
        ProposalDetails storage details = _proposalDetails[proposalId];
        if (details.descriptionHash == bytes32(0)) {
            details.proposer = proposer;
            details.targets = targets;
            details.values = values;
            details.signatures = signatures;
            details.calldatas = calldatas;
            details.descriptionHash = descriptionHash;
        }
    }
    function proposals(
        uint256 proposalId
    )
        public
        view
        virtual
        override
        returns (
            uint256 id,
            address proposer,
            uint256 eta,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes,
            bool canceled,
            bool executed
        )
    {
        id = proposalId;
        eta = proposalEta(proposalId);
        startBlock = proposalSnapshot(proposalId);
        endBlock = proposalDeadline(proposalId);
        ProposalDetails storage details = _proposalDetails[proposalId];
        proposer = details.proposer;
        forVotes = details.forVotes;
        againstVotes = details.againstVotes;
        abstainVotes = details.abstainVotes;
        ProposalState currentState = state(proposalId);
        canceled = currentState == ProposalState.Canceled;
        executed = currentState == ProposalState.Executed;
    }
    function getActions(
        uint256 proposalId
    )
        public
        view
        virtual
        override
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        ProposalDetails storage details = _proposalDetails[proposalId];
        return (details.targets, details.values, details.signatures, details.calldatas);
    }
    function getReceipt(uint256 proposalId, address voter) public view virtual override returns (Receipt memory) {
        return _proposalDetails[proposalId].receipts[voter];
    }
    function quorumVotes() public view virtual override returns (uint256) {
        return quorum(clock() - 1);
    }
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalDetails[proposalId].receipts[account].hasVoted;
    }
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalDetails storage details = _proposalDetails[proposalId];
        return quorum(proposalSnapshot(proposalId)) <= details.forVotes;
    }
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalDetails storage details = _proposalDetails[proposalId];
        return details.forVotes > details.againstVotes;
    }
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory 
    ) internal virtual override {
        ProposalDetails storage details = _proposalDetails[proposalId];
        Receipt storage receipt = details.receipts[account];
        require(!receipt.hasVoted, "GovernorCompatibilityBravo: vote already cast");
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = SafeCast.toUint96(weight);
        if (support == uint8(VoteType.Against)) {
            details.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            details.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            details.abstainVotes += weight;
        } else {
            revert("GovernorCompatibilityBravo: invalid vote type");
        }
    }
}