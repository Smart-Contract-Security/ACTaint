pragma solidity 0.8.9;
import "../Interface/IPriceChainLink.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { IChainLinkAggregator } from "../Interface/IChainLinkAggregator.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../lib/JOJOConstant.sol";
contract JOJOOracleAdaptor is IPriceChainLink, Ownable {
    address public immutable chainlink;
    uint256 public immutable decimalsCorrection;
    uint256 public immutable heartbeatInterval;
    address public immutable USDCSource;
    constructor(address _source, uint256 _decimalCorrection, uint256 _heartbeatInterval, address _USDCSource) {
        chainlink = _source;
        decimalsCorrection = 10 ** _decimalCorrection;
        heartbeatInterval = _heartbeatInterval;
        USDCSource = _USDCSource;
    }
    function getAssetPrice() external view override returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = IChainLinkAggregator(chainlink).latestRoundData();
        (, int256 USDCPrice,, uint256 USDCUpdatedAt,) = IChainLinkAggregator(USDCSource).latestRoundData();
        require(block.timestamp - updatedAt <= heartbeatInterval, "ORACLE_HEARTBEAT_FAILED");
        require(block.timestamp - USDCUpdatedAt <= heartbeatInterval, "USDC_ORACLE_HEARTBEAT_FAILED");
        uint256 tokenPrice = (SafeCast.toUint256(price) * 1e8) / SafeCast.toUint256(USDCPrice);
        return tokenPrice * JOJOConstant.ONE / decimalsCorrection;
    }
}