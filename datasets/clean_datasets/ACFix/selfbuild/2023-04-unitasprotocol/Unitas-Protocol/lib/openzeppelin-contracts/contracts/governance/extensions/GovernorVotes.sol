pragma solidity ^0.8.0;
import "../Governor.sol";
import "../utils/IVotes.sol";
abstract contract GovernorVotes is Governor {
    IVotes public immutable token;
    constructor(IVotes tokenAddress) {
        token = tokenAddress;
    }
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory 
    ) internal view virtual override returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }
}