pragma solidity ^0.8.0;
import "./ERC20VotesUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC20VotesCompUpgradeable is Initializable, ERC20VotesUpgradeable {
    function __ERC20VotesComp_init() internal onlyInitializing {
    }
    function __ERC20VotesComp_init_unchained() internal onlyInitializing {
    }
    function getCurrentVotes(address account) external view virtual returns (uint96) {
        return SafeCastUpgradeable.toUint96(getVotes(account));
    }
    function getPriorVotes(address account, uint256 blockNumber) external view virtual returns (uint96) {
        return SafeCastUpgradeable.toUint96(getPastVotes(account, blockNumber));
    }
    function _maxSupply() internal view virtual override returns (uint224) {
        return type(uint96).max;
    }
    uint256[50] private __gap;
}