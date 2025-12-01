pragma solidity ^0.8.0;
import "../IGovernorUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract IGovernorTimelockUpgradeable is Initializable, IGovernorUpgradeable {
    function __IGovernorTimelock_init() internal onlyInitializing {
    }
    function __IGovernorTimelock_init_unchained() internal onlyInitializing {
    }
    event ProposalQueued(uint256 proposalId, uint256 eta);
    function timelock() public view virtual returns (address);
    function proposalEta(uint256 proposalId) public view virtual returns (uint256);
    function queue(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public virtual returns (uint256 proposalId);
    uint256[50] private __gap;
}