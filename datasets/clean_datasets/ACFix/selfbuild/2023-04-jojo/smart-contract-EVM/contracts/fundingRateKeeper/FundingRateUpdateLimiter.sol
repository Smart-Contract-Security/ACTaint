pragma solidity 0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../intf/IDealer.sol";
import "../intf/IPerpetual.sol";
import "../intf/IMarkPriceSource.sol";
import "../utils/SignedDecimalMath.sol";
import "../lib/Types.sol";
contract FundingRateUpdateLimiter is Ownable {
    using SignedDecimalMath for int256;
    address immutable dealer;
    uint8 immutable speedMultiplier;
    mapping(address => uint256) public fundingRateUpdateTimestamp;
    constructor(address _dealer, uint8 _speedMultiplier) {
        dealer = _dealer;
        speedMultiplier = _speedMultiplier;
    }
    function updateFundingRate(
        address[] calldata perpList,
        int256[] calldata rateList
    ) external onlyOwner {
        for (uint256 i = 0; i < perpList.length;) {
            address perp = perpList[i];
            int256 oldRate = IPerpetual(perp).getFundingRate();
            uint256 maxChange = getMaxChange(perp);
            require(
                (rateList[i] - oldRate).abs() <= maxChange,
                "FUNDING_RATE_CHANGE_TOO_MUCH"
            );
            fundingRateUpdateTimestamp[perp] = block.timestamp;
            unchecked {
                ++i;
            }
        }
        IDealer(dealer).updateFundingRate(perpList, rateList);
    }
    function getMaxChange(address perp) public view returns (uint256) {
        Types.RiskParams memory params = IDealer(dealer).getRiskParams(perp);
        uint256 markPrice = IMarkPriceSource(params.markPriceSource)
            .getMarkPrice();
        uint256 timeInterval = block.timestamp -
            fundingRateUpdateTimestamp[perp];
        uint256 maxChangeRate = (speedMultiplier *
            timeInterval *
            params.liquidationThreshold) / (1 days);
        uint256 maxChange = (maxChangeRate * markPrice) / Types.ONE;
        return maxChange;
    }
}