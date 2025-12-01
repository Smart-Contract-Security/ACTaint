pragma solidity ^0.8.0;
import "./TimelockControllerUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
contract TimelockControllerWith46MigrationUpgradeable is Initializable, TimelockControllerUpgradeable {
    function __TimelockControllerWith46Migration_init(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) internal onlyInitializing {
        __TimelockController_init_unchained(minDelay, proposers, executors);
    }
    function __TimelockControllerWith46Migration_init_unchained(
        uint256,
        address[] memory,
        address[] memory
    ) internal onlyInitializing {}
    function migrateTo46() public virtual {
        require(
            getRoleAdmin(PROPOSER_ROLE) == TIMELOCK_ADMIN_ROLE && getRoleAdmin(CANCELLER_ROLE) == DEFAULT_ADMIN_ROLE,
            "TimelockController: already migrated"
        );
        _setRoleAdmin(CANCELLER_ROLE, TIMELOCK_ADMIN_ROLE);
    }
    uint256[50] private __gap;
}