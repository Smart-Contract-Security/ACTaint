pragma solidity ^0.8.0;
import "../GovernorUpgradeable.sol";
import "../../token/ERC20/extensions/ERC20VotesCompUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract GovernorVotesCompUpgradeable is Initializable, GovernorUpgradeable {
    ERC20VotesCompUpgradeable public token;
    function __GovernorVotesComp_init(ERC20VotesCompUpgradeable token_) internal onlyInitializing {
        __GovernorVotesComp_init_unchained(token_);
    }
    function __GovernorVotesComp_init_unchained(ERC20VotesCompUpgradeable token_) internal onlyInitializing {
        token = token_;
    }
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory 
    ) internal view virtual override returns (uint256) {
        return token.getPriorVotes(account, blockNumber);
    }
    uint256[50] private __gap;
}