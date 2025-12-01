pragma solidity ^0.8.0;
import "../GovernorUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract GovernorProposalThresholdUpgradeable is Initializable, GovernorUpgradeable {
    function __GovernorProposalThreshold_init() internal onlyInitializing {
    }
    function __GovernorProposalThreshold_init_unchained() internal onlyInitializing {
    }
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public virtual override returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }
    uint256[50] private __gap;
}