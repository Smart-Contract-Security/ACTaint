pragma solidity ^0.8.0;
import "./ERC20Votes.sol";
abstract contract ERC20VotesComp is ERC20Votes {
    function getCurrentVotes(address account) external view virtual returns (uint96) {
        return SafeCast.toUint96(getVotes(account));
    }
    function getPriorVotes(address account, uint256 blockNumber) external view virtual returns (uint96) {
        return SafeCast.toUint96(getPastVotes(account, blockNumber));
    }
    function _maxSupply() internal view virtual override returns (uint224) {
        return type(uint96).max;
    }
}