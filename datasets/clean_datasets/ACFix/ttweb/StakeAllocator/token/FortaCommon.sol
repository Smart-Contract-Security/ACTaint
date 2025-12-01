pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../tools/ENSReverseRegistration.sol";
import "../errors/GeneralErrors.sol";
import "../components/utils/IVersioned.sol";
abstract contract FortaCommon is AccessControlUpgradeable, ERC20VotesUpgradeable, UUPSUpgradeable, IVersioned {
    bytes32 public constant ADMIN_ROLE       = keccak256("ADMIN_ROLE");
    bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
    bytes32 public constant WHITELIST_ROLE   = keccak256("WHITELIST_ROLE");
    bool private deprecated_whitelistDisabled;
    constructor() initializer {}
    function __FortaCommon_init(address admin) internal initializer {
        if (admin == address(0)) revert ZeroAddress("admin");
        __AccessControl_init();
        __ERC20_init("Forta", "FORT");
        __ERC20Permit_init("Forta");
        __UUPSUpgradeable_init();
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(WHITELISTER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(WHITELIST_ROLE, WHITELISTER_ROLE);
        _grantRole(ADMIN_ROLE, admin);
    }
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(ADMIN_ROLE) {
    }
    function setName(address ensRegistry, string calldata ensName) external onlyRole(ADMIN_ROLE) {
        ENSReverseRegistration.setName(ensRegistry, ensName);
    }
    uint256[49] private __gap; 
}