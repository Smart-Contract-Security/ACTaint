pragma solidity ^0.8.9;
import "../../src/Interface/IChainLinkAggregator.sol";
contract MockUSDCPrice is IChainLinkAggregator {
    function decimals() external view returns (uint8) {
        return 18;
    }
    function description() external view returns (string memory) {
        return "";
    }
    function version() external view returns (uint256) {
        return 1;
    }
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, 1, 1, 1, 1);
    }
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, 100000000, 1, 1, 1);
    }
}