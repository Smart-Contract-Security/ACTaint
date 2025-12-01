pragma solidity ^0.8.0;
import "../ERC20Upgradeable.sol";
import "../../../security/PausableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC20PausableUpgradeable is Initializable, ERC20Upgradeable, PausableUpgradeable {
    function __ERC20Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }
    function __ERC20Pausable_init_unchained() internal onlyInitializing {
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
    uint256[50] private __gap;
}