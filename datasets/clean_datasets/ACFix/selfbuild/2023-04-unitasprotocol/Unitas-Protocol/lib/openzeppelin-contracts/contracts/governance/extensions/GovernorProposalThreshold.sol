pragma solidity ^0.8.0;
import "../Governor.sol";
abstract contract GovernorProposalThreshold is Governor {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }
}