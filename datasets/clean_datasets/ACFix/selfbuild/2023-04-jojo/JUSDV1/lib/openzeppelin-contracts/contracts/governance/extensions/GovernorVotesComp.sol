pragma solidity ^0.8.0;
import "../Governor.sol";
import "../../token/ERC20/extensions/ERC20VotesComp.sol";
abstract contract GovernorVotesComp is Governor {
    ERC20VotesComp public immutable token;
    constructor(ERC20VotesComp token_) {
        token = token_;
    }
    function clock() public view virtual override returns (uint48) {
        try token.clock() returns (uint48 timepoint) {
            return timepoint;
        } catch {
            return SafeCast.toUint48(block.number);
        }
    }
    function CLOCK_MODE() public view virtual override returns (string memory) {
        try token.CLOCK_MODE() returns (string memory clockmode) {
            return clockmode;
        } catch {
            return "mode=blocknumber&from=default";
        }
    }
    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory 
    ) internal view virtual override returns (uint256) {
        return token.getPriorVotes(account, timepoint);
    }
}