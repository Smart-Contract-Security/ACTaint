pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Roles.sol";
import "./utils/AccessManaged.sol";
import "./utils/IVersioned.sol";
import "./utils/ForwardedContext.sol";
import "./utils/Routed.sol";
import "../tools/ENSReverseRegistration.sol";
abstract contract BaseComponentUpgradeable is
    ForwardedContext,
    AccessManagedUpgradeable,
    RoutedUpgradeable,
    Multicall,
    UUPSUpgradeable,
    IVersioned
{
    function __BaseComponentUpgradeable_init(address __manager) internal initializer {
        __AccessManaged_init(__manager);
        __UUPSUpgradeable_init();
    }
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {
    }
    function setName(address ensRegistry, string calldata ensName) public onlyRole(ENS_MANAGER_ROLE) {
        ENSReverseRegistration.setName(ensRegistry, ensName);
    }
    function _msgSender() internal view virtual override(ContextUpgradeable, ForwardedContext) returns (address sender) {
        return super._msgSender();
    }
    function _msgData() internal view virtual override(ContextUpgradeable, ForwardedContext) returns (bytes calldata) {
        return super._msgData();
    }
    uint256[50] private __gap;
}