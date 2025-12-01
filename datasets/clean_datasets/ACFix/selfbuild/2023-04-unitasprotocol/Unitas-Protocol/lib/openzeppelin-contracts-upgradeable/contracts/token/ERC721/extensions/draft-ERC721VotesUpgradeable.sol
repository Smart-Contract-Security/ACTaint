pragma solidity ^0.8.0;
import "../ERC721Upgradeable.sol";
import "../../../governance/utils/VotesUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC721VotesUpgradeable is Initializable, ERC721Upgradeable, VotesUpgradeable {
    function __ERC721Votes_init() internal onlyInitializing {
    }
    function __ERC721Votes_init_unchained() internal onlyInitializing {
    }
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        _transferVotingUnits(from, to, 1);
        super._afterTokenTransfer(from, to, tokenId);
    }
    function _afterConsecutiveTokenTransfer(
        address from,
        address to,
        uint256 first,
        uint96 size
    ) internal virtual override {
        _transferVotingUnits(from, to, size);
        super._afterConsecutiveTokenTransfer(from, to, first, size);
    }
    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account);
    }
    uint256[50] private __gap;
}