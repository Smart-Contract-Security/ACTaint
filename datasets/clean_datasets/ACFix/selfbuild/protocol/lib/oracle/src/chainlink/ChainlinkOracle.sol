pragma solidity ^0.8.17;
import {IOracle} from "../core/IOracle.sol";
import {Ownable} from "../utils/Ownable.sol";
import {Errors} from "../utils/Errors.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";
contract ChainlinkOracle is Ownable, IOracle {
    AggregatorV3Interface immutable ethUsdPriceFeed;
    mapping(address => AggregatorV3Interface) public feed;
    mapping(address => uint) public heartBeatOf;
    event UpdateFeed(address indexed token, address indexed feed);
    constructor(AggregatorV3Interface _ethUsdPriceFeed) Ownable(msg.sender) {
        ethUsdPriceFeed = _ethUsdPriceFeed;
    }
    function getPrice(address token) external view virtual returns (uint) {
        (, int answer,, uint updatedAt,) =
            feed[token].latestRoundData();
        if (block.timestamp - updatedAt >= heartBeatOf[token])
            revert Errors.StalePrice(token, address(feed[token]));
        if (answer <= 0)
            revert Errors.NegativePrice(token, address(feed[token]));
        return (
            (uint(answer)*1e18)/getEthPrice()
        );
    }
    function getEthPrice() internal view returns (uint) {
        (, int answer,, uint updatedAt,) =
            ethUsdPriceFeed.latestRoundData();
        if (block.timestamp - updatedAt >= 86400)
            revert Errors.StalePrice(address(0), address(ethUsdPriceFeed));
        if (answer <= 0)
            revert Errors.NegativePrice(address(0), address(ethUsdPriceFeed));
        return uint(answer);
    }
    function setFeed(
        address token,
        AggregatorV3Interface _feed,
        uint heartBeat
    ) external adminOnly {
        if (_feed.decimals() != 8) revert Errors.IncorrectDecimals();
        feed[token] = _feed;
        heartBeatOf[token] = heartBeat;
        emit UpdateFeed(token, address(_feed));
    }
}