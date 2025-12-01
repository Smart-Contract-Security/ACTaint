pragma solidity 0.8.9;
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../intf/IPerpetual.sol";
import "../intf/IMarkPriceSource.sol";
import "../utils/SignedDecimalMath.sol";
import "../utils/Errors.sol";
import "./Types.sol";
import "./Position.sol";
library Liquidation {
    using SignedDecimalMath for int256;
    event BeingLiquidated(
        address indexed perp,
        address indexed liquidatedTrader,
        int256 paperChange,
        int256 creditChange,
        uint256 positionSerialNum
    );
    event JoinLiquidation(
        address indexed perp,
        address indexed liquidator,
        address indexed liquidatedTrader,
        int256 paperChange,
        int256 creditChange,
        uint256 positionSerialNum
    );
    event ChargeInsurance(
        address indexed perp,
        address indexed liquidatedTrader,
        uint256 fee
    );
    event HandleBadDebt(
        address indexed liquidatedTrader,
        int256 primaryCredit,
        uint256 secondaryCredit
    );
    function getTotalExposure(Types.State storage state, address trader)
        public
        view
        returns (
            int256 netPositionValue,
            uint256 exposure,
            uint256 maintenanceMargin
        )
    {
        for (uint256 i = 0; i < state.openPositions[trader].length; ) {
            (int256 paperAmount, int256 creditAmount) = IPerpetual(
                state.openPositions[trader][i]
            ).balanceOf(trader);
            Types.RiskParams storage params = state.perpRiskParams[
                state.openPositions[trader][i]
            ];
            int256 price = SafeCast.toInt256(
                IMarkPriceSource(params.markPriceSource).getMarkPrice()
            );
            netPositionValue += paperAmount.decimalMul(price) + creditAmount;
            uint256 exposureIncrement = paperAmount.decimalMul(price).abs();
            exposure += exposureIncrement;
            maintenanceMargin +=
                (exposureIncrement * params.liquidationThreshold) /
                Types.ONE;
            unchecked {
                ++i;
            }
        }
    }
    function _isSafe(Types.State storage state, address trader)
        internal
        view
        returns (bool)
    {
        (
            int256 netPositionValue,
            ,
            uint256 maintenanceMargin
        ) = getTotalExposure(state, trader);
        return
            netPositionValue +
                state.primaryCredit[trader] +
                SafeCast.toInt256(state.secondaryCredit[trader]) >=
            SafeCast.toInt256(maintenanceMargin);
    }
    function _isSolidSafe(Types.State storage state, address trader)
        internal
        view
        returns (bool)
    {
        (
            int256 netPositionValue,
            ,
            uint256 maintenanceMargin
        ) = getTotalExposure(state, trader);
        return
            netPositionValue + state.primaryCredit[trader] >= 0 &&
            netPositionValue +
                state.primaryCredit[trader] +
                SafeCast.toInt256(state.secondaryCredit[trader]) >=
            SafeCast.toInt256(maintenanceMargin);
    }
    function _isAllSafe(
        Types.State storage state,
        address[] calldata traderList
    ) internal view returns (bool) {
        uint256 totalPerpNum = state.registeredPerp.length;
        address[] memory perpList = new address[](totalPerpNum);
        int256[] memory markPriceCache = new int256[](totalPerpNum);
        for (uint256 i = 0; i < traderList.length; ) {
            address trader = traderList[i];
            uint256 maintenanceMargin;
            int256 netValue = state.primaryCredit[trader] +
                SafeCast.toInt256(state.secondaryCredit[trader]);
            for (uint256 j = 0; j < state.openPositions[trader].length; ) {
                address perp = state.openPositions[trader][j];
                Types.RiskParams storage params = state.perpRiskParams[perp];
                int256 markPrice;
                for (uint256 k = 0; k < totalPerpNum; ) {
                    if (perpList[k] == perp) {
                        markPrice = markPriceCache[k];
                        break;
                    }
                    if (perpList[k] == address(0)) {
                        markPrice = SafeCast.toInt256(
                            IMarkPriceSource(params.markPriceSource)
                                .getMarkPrice()
                        );
                        perpList[k] = perp;
                        markPriceCache[k] = markPrice;
                        break;
                    }
                    unchecked {
                        ++k;
                    }
                }
                (int256 paperAmount, int256 credit) = IPerpetual(perp)
                    .balanceOf(trader);
                maintenanceMargin +=
                    (paperAmount.decimalMul(markPrice).abs() *
                        params.liquidationThreshold) /
                    Types.ONE;
                netValue += paperAmount.decimalMul(markPrice) + credit;
                unchecked {
                    ++j;
                }
            }
            if (netValue < SafeCast.toInt256(maintenanceMargin)) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }
    function getLiquidationPrice(
        Types.State storage state,
        address trader,
        address perp
    ) external view returns (uint256 liquidationPrice) {
        int256 maintenanceMarginPrime;
        int256 netValuePrime = state.primaryCredit[trader] +
            SafeCast.toInt256(state.secondaryCredit[trader]);
        for (uint256 i = 0; i < state.openPositions[trader].length; ) {
            address p = state.openPositions[trader][i];
            if (perp != p) {
                (
                    int256 paperAmountPrime,
                    int256 creditAmountPrime
                ) = IPerpetual(p).balanceOf(trader);
                Types.RiskParams storage params = state.perpRiskParams[p];
                int256 price = SafeCast.toInt256(
                    IMarkPriceSource(params.markPriceSource).getMarkPrice()
                );
                netValuePrime +=
                    paperAmountPrime.decimalMul(price) +
                    creditAmountPrime;
                maintenanceMarginPrime += SafeCast.toInt256(
                    (paperAmountPrime.decimalMul(price).abs() *
                        params.liquidationThreshold) / Types.ONE
                );
            }
            unchecked {
                ++i;
            }
        }
        (int256 paperAmount, int256 creditAmount) = IPerpetual(perp).balanceOf(
            trader
        );
        if (paperAmount == 0) {
            return 0;
        }
        int256 multiplier = paperAmount > 0
            ? SafeCast.toInt256(
                Types.ONE - state.perpRiskParams[perp].liquidationThreshold
            )
            : SafeCast.toInt256(
                Types.ONE + state.perpRiskParams[perp].liquidationThreshold
            );
        int256 liqPrice = (maintenanceMarginPrime -
            netValuePrime -
            creditAmount).decimalDiv(paperAmount).decimalDiv(multiplier);
        return liqPrice < 0 ? 0 : uint256(liqPrice);
    }
    function getLiquidateCreditAmount(
        Types.State storage state,
        address perp,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        public
        view
        returns (
            int256 liqtorPaperChange,
            int256 liqtorCreditChange,
            uint256 insuranceFee
        )
    {
        require(!_isSafe(state, liquidatedTrader), Errors.ACCOUNT_IS_SAFE);
        (int256 brokenPaperAmount, ) = IPerpetual(perp).balanceOf(
            liquidatedTrader
        );
        require(brokenPaperAmount != 0, Errors.TRADER_HAS_NO_POSITION);
        require(
            requestPaperAmount * brokenPaperAmount > 0,
            Errors.LIQUIDATION_REQUEST_AMOUNT_WRONG
        );
        liqtorPaperChange = requestPaperAmount.abs() > brokenPaperAmount.abs()
            ? brokenPaperAmount
            : requestPaperAmount;
        Types.RiskParams storage params = state.perpRiskParams[perp];
        uint256 price = IMarkPriceSource(params.markPriceSource).getMarkPrice();
        uint256 priceOffset = (price * params.liquidationPriceOff) / Types.ONE;
        price = liqtorPaperChange > 0
            ? price - priceOffset
            : price + priceOffset;
        liqtorCreditChange =
            -1 *
            liqtorPaperChange.decimalMul(SafeCast.toInt256(price));
        insuranceFee =
            (liqtorCreditChange.abs() * params.insuranceFeeRate) /
            Types.ONE;
    }
    function requestLiquidation(
        Types.State storage state,
        address perp,
        address executor,
        address liquidator,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        external
        returns (
            int256 liqtorPaperChange,
            int256 liqtorCreditChange,
            int256 liqedPaperChange,
            int256 liqedCreditChange
        )
    {
        require(
            executor == liquidator ||
                state.operatorRegistry[liquidator][executor],
            Errors.INVALID_LIQUIDATION_EXECUTOR
        );
        require(
            liquidatedTrader != liquidator,
            Errors.SELF_LIQUIDATION_NOT_ALLOWED
        );
        uint256 insuranceFee;
        (
            liqtorPaperChange,
            liqtorCreditChange,
            insuranceFee
        ) = getLiquidateCreditAmount(
            state,
            perp,
            liquidatedTrader,
            requestPaperAmount
        );
        state.primaryCredit[state.insurance] += SafeCast.toInt256(insuranceFee);
        liqedCreditChange = liqtorCreditChange * -1 - SafeCast.toInt256(insuranceFee);
        liqedPaperChange = liqtorPaperChange * -1;
        uint256 ltSN = state.positionSerialNum[liquidatedTrader][perp];
        uint256 liquidatorSN = state.positionSerialNum[liquidator][perp];
        emit BeingLiquidated(
            perp,
            liquidatedTrader,
            liqedPaperChange,
            liqedCreditChange,
            ltSN
        );
        emit JoinLiquidation(
            perp,
            liquidator,
            liquidatedTrader,
            liqtorPaperChange,
            liqtorCreditChange,
            liquidatorSN
        );
        emit ChargeInsurance(perp, liquidatedTrader, insuranceFee);
    }
    function getMarkPrice(Types.State storage state, address perp)
        external
        view
        returns (uint256 price)
    {
        price = IMarkPriceSource(state.perpRiskParams[perp].markPriceSource)
            .getMarkPrice();
    }
    function handleBadDebt(Types.State storage state, address liquidatedTrader)
        external
    {
        if (
            state.openPositions[liquidatedTrader].length == 0 &&
            !Liquidation._isSafe(state, liquidatedTrader)
        ) {
            int256 primaryCredit = state.primaryCredit[liquidatedTrader];
            uint256 secondaryCredit = state.secondaryCredit[liquidatedTrader];
            state.primaryCredit[state.insurance] += primaryCredit;
            state.secondaryCredit[state.insurance] += secondaryCredit;
            state.primaryCredit[liquidatedTrader] = 0;
            state.secondaryCredit[liquidatedTrader] = 0;
            emit HandleBadDebt(
                liquidatedTrader,
                primaryCredit,
                secondaryCredit
            );
        }
    }
}