pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./JOJOStorage.sol";
import "../utils/Errors.sol";
import "../intf/IDealer.sol";
import "../lib/Liquidation.sol";
import "../lib/Trading.sol";
abstract contract JOJOView is JOJOStorage, IDealer {
    function getRiskParams(address perp)
        external
        view
        returns (Types.RiskParams memory params)
    {
        params = state.perpRiskParams[perp];
    }
    function getAllRegisteredPerps() external view returns (address[] memory) {
        return state.registeredPerp;
    }
    function getMarkPrice(address perp) external view returns (uint256) {
        return Liquidation.getMarkPrice(state, perp);
    }
    function getPositions(address trader)
        external
        view
        returns (address[] memory)
    {
        return state.openPositions[trader];
    }
    function getCreditOf(address trader)
        external
        view
        returns (
            int256 primaryCredit,
            uint256 secondaryCredit,
            uint256 pendingPrimaryWithdraw,
            uint256 pendingSecondaryWithdraw,
            uint256 executionTimestamp
        )
    {
        primaryCredit = state.primaryCredit[trader];
        secondaryCredit = state.secondaryCredit[trader];
        pendingPrimaryWithdraw = state.pendingPrimaryWithdraw[trader];
        pendingSecondaryWithdraw = state.pendingSecondaryWithdraw[trader];
        executionTimestamp = state.withdrawExecutionTimestamp[trader];
    }
    function isOrderSenderValid(address orderSender)
        external
        view
        returns (bool)
    {
        return state.validOrderSender[orderSender];
    }
    function isOperatorValid(address client, address operator)
        external
        view
        returns (bool)
    {
        return state.operatorRegistry[client][operator];
    }
    function isSafe(address trader) external view returns (bool safe) {
        return Liquidation._isSafe(state, trader);
    }
    function isAllSafe(address[] calldata traderList)
        external
        view
        returns (bool safe)
    {
        return Liquidation._isAllSafe(state, traderList);
    }
    function getFundingRate(address perp) external view returns (int256) {
        return IPerpetual(perp).getFundingRate();
    }
    function getTraderRisk(address trader)
        external
        view
        returns (
            int256 netValue,
            uint256 exposure,
            uint256 maintenanceMargin
        )
    {
        int256 positionNetValue;
        (positionNetValue, exposure, maintenanceMargin) = Liquidation
            .getTotalExposure(state, trader);
        netValue =
            positionNetValue +
            state.primaryCredit[trader] +
            SafeCast.toInt256(state.secondaryCredit[trader]);
    }
    function getLiquidationPrice(address trader, address perp)
        external
        view
        returns (uint256 liquidationPrice)
    {
        return Liquidation.getLiquidationPrice(state, trader, perp);
    }
    function getLiquidationCost(
        address perp,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        external
        view
        returns (int256 liqtorPaperChange, int256 liqtorCreditChange)
    {
        (liqtorPaperChange, liqtorCreditChange, ) = Liquidation
            .getLiquidateCreditAmount(
                state,
                perp,
                liquidatedTrader,
                requestPaperAmount
            );
    }
    function getOrderFilledAmount(bytes32 orderHash)
        external
        view
        returns (uint256 filledAmount)
    {
        filledAmount = state.orderFilledPaperAmount[orderHash];
    }
    function getSetOperatorCallData(address operator, bool isValid)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature("setOperator(address,bool)", operator, isValid);
    }
    function getRequestWithdrawCallData(uint256 primaryAmount, uint256 secondaryAmount)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature("requestWithdraw(uint256,uint256)", primaryAmount, secondaryAmount);
    }
    function getExecuteWithdrawCallData(address to, bool isInternal)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature("executeWithdraw(address,bool)", to, isInternal);
    }
}