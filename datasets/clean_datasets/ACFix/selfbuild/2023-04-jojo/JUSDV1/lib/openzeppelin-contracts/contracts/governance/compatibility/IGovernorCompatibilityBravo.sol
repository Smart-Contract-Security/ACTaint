pragma solidity ^0.8.0;
import "../IGovernor.sol";
abstract contract IGovernorCompatibilityBravo is IGovernor {
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 eta;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
    }
    function quorumVotes() public view virtual returns (uint256);
    function proposals(
        uint256
    )
        public
        view
        virtual
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
        );
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256);
    function queue(uint256 proposalId) public virtual;
    function execute(uint256 proposalId) public payable virtual;
    function cancel(uint256 proposalId) public virtual;
    function getActions(
        uint256 proposalId
    )
        public
        view
        virtual
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );
    function getReceipt(uint256 proposalId, address voter) public view virtual returns (Receipt memory);
}