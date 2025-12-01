pragma solidity ^0.8.17;
import {ChainlinkOracle} from "./ChainlinkOracle.sol";
import {Errors} from "../utils/Errors.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
contract ArbiChainlinkOracle is ChainlinkOracle {
    AggregatorV3Interface immutable sequencer;
    uint256 private constant GRACE_PERIOD_TIME = 3600;
    constructor(
        AggregatorV3Interface _ethUsdPriceFeed,
        AggregatorV3Interface _sequencer
    )
        ChainlinkOracle(_ethUsdPriceFeed)
    {
        sequencer = _sequencer;
    }
    function getPrice(address token) external view override returns (uint) {
        if (!isSequencerActive()) revert Errors.L2SequencerUnavailable();
        (, int answer,,,) =
            feed[token].latestRoundData();
        if (answer < 0)
            revert Errors.NegativePrice(token, address(feed[token]));
        return (
            (uint(answer)*1e18)/getEthPrice()
        );
    }
    function isSequencerActive() internal view returns (bool) {
        (, int256 answer, uint256 startedAt,,) = sequencer.latestRoundData();
        if (block.timestamp - startedAt <= GRACE_PERIOD_TIME || answer == 1)
            return false;
        return true;
    }
}