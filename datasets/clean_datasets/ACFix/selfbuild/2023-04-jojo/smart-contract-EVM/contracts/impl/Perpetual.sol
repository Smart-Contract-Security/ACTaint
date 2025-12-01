pragma solidity 0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../intf/IDealer.sol";
import "../intf/IPerpetual.sol";
import "../utils/SignedDecimalMath.sol";
contract Perpetual is Ownable, IPerpetual {
    using SignedDecimalMath for int256;
    struct balance {
        int128 paper;
        int128 reducedCredit;
    }
    mapping(address => balance) balanceMap;
    int256 fundingRate;
    event BalanceChange(
        address indexed trader,
        int256 paperChange,
        int256 creditChange
    );
    event UpdateFundingRate(int256 oldFundingRate, int256 newFundingRate);
    constructor(address _owner) Ownable() {
        transferOwnership(_owner);
    }
    function balanceOf(
        address trader
    ) external view returns (int256 paper, int256 credit) {
        paper = int256(balanceMap[trader].paper);
        credit =
            paper.decimalMul(fundingRate) +
            int256(balanceMap[trader].reducedCredit);
    }
    function updateFundingRate(int256 newFundingRate) external onlyOwner {
        int256 oldFundingRate = fundingRate;
        fundingRate = newFundingRate;
        emit UpdateFundingRate(oldFundingRate, newFundingRate);
    }
    function getFundingRate() external view returns (int256) {
        return fundingRate;
    }
    function trade(bytes calldata tradeData) external {
        (
            address[] memory traderList,
            int256[] memory paperChangeList,
            int256[] memory creditChangeList
        ) = IDealer(owner()).approveTrade(msg.sender, tradeData);
        for (uint256 i = 0; i < traderList.length; ) {
            _settle(traderList[i], paperChangeList[i], creditChangeList[i]);
            unchecked {
                ++i;
            }
        }
        require(IDealer(owner()).isAllSafe(traderList), "TRADER_NOT_SAFE");
    }
    function liquidate(
        address liquidator,
        address liquidatedTrader,
        int256 requestPaper,
        int256 expectCredit
    ) external returns (int256 liqtorPaperChange, int256 liqtorCreditChange) {
        int256 liqedPaperChange;
        int256 liqedCreditChange;
        (
            liqtorPaperChange,
            liqtorCreditChange,
            liqedPaperChange,
            liqedCreditChange
        ) = IDealer(owner()).requestLiquidation(
            msg.sender,
            liquidator,
            liquidatedTrader,
            requestPaper
        );
        if (liqtorPaperChange < 0) {
            require(
                liqtorCreditChange * requestPaper <=
                    expectCredit * liqtorPaperChange,
                "LIQUIDATION_PRICE_PROTECTION"
            );
        } else {
            require(
                liqtorCreditChange * requestPaper >=
                    expectCredit * liqtorPaperChange,
                "LIQUIDATION_PRICE_PROTECTION"
            );
        }
        _settle(liquidatedTrader, liqedPaperChange, liqedCreditChange);
        _settle(liquidator, liqtorPaperChange, liqtorCreditChange);
        require(IDealer(owner()).isSafe(liquidator), "LIQUIDATOR_NOT_SAFE");
        if (balanceMap[liquidatedTrader].paper == 0) {
            IDealer(owner()).handleBadDebt(liquidatedTrader);
        }
    }
    function _settle(
        address trader,
        int256 paperChange,
        int256 creditChange
    ) internal {
        bool isNewPosition = balanceMap[trader].paper == 0;
        int256 rate = fundingRate; 
        int256 credit = int256(balanceMap[trader].paper).decimalMul(rate) +
            int256(balanceMap[trader].reducedCredit) +
            creditChange;
        int128 newPaper = balanceMap[trader].paper +
            SafeCast.toInt128(paperChange);
        int128 newReducedCredit = SafeCast.toInt128(
            credit - int256(newPaper).decimalMul(rate)
        );
        balanceMap[trader].paper = newPaper;
        balanceMap[trader].reducedCredit = newReducedCredit;
        emit BalanceChange(trader, paperChange, creditChange);
        if (isNewPosition) {
            IDealer(owner()).openPosition(trader);
        }
        if (newPaper == 0) {
            IDealer(owner()).realizePnl(
                trader,
                balanceMap[trader].reducedCredit
            );
            balanceMap[trader].reducedCredit = 0;
        }
    }
}