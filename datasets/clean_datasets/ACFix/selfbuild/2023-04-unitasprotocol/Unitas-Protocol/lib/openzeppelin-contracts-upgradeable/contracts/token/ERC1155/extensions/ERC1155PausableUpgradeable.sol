pragma solidity ^0.8.0;
import "../ERC1155Upgradeable.sol";
import "../../../security/PausableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC1155PausableUpgradeable is Initializable, ERC1155Upgradeable, PausableUpgradeable {
    function __ERC1155Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }
    function __ERC1155Pausable_init_unchained() internal onlyInitializing {
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        require(!paused(), "ERC1155Pausable: token transfer while paused");
    }
    uint256[50] private __gap;
}