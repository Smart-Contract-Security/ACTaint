pragma solidity ^0.8.0;
import "../ERC721Upgradeable.sol";
import "../../../security/PausableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC721PausableUpgradeable is Initializable, ERC721Upgradeable, PausableUpgradeable {
    function __ERC721Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }
    function __ERC721Pausable_init_unchained() internal onlyInitializing {
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        require(!paused(), "ERC721Pausable: token transfer while paused");
    }
    function _beforeConsecutiveTokenTransfer(
        address from,
        address to,
        uint256 first,
        uint96 size
    ) internal virtual override {
        super._beforeConsecutiveTokenTransfer(from, to, first, size);
        require(!paused(), "ERC721Pausable: token transfer while paused");
    }
    uint256[50] private __gap;
}