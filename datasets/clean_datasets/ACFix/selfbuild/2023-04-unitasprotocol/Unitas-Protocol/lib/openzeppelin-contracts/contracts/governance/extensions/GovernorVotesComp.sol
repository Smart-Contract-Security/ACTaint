pragma solidity ^0.8.0;
import "../Governor.sol";
import "../../token/ERC20/extensions/ERC20VotesComp.sol";
abstract contract GovernorVotesComp is Governor {
    ERC20VotesComp public immutable token;
    constructor(ERC20VotesComp token_) {
        token = token_;
    }
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory 
    ) internal view virtual override returns (uint256) {
        return token.getPriorVotes(account, blockNumber);
    }
}