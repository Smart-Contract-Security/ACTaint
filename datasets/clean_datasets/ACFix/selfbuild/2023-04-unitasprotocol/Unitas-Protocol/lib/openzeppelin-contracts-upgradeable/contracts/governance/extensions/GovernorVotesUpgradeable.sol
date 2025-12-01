pragma solidity ^0.8.0;
import "../GovernorUpgradeable.sol";
import "../utils/IVotesUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract GovernorVotesUpgradeable is Initializable, GovernorUpgradeable {
    IVotesUpgradeable public token;
    function __GovernorVotes_init(IVotesUpgradeable tokenAddress) internal onlyInitializing {
        __GovernorVotes_init_unchained(tokenAddress);
    }
    function __GovernorVotes_init_unchained(IVotesUpgradeable tokenAddress) internal onlyInitializing {
        token = tokenAddress;
    }
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory 
    ) internal view virtual override returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }
    uint256[50] private __gap;
}