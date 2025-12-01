pragma solidity 0.8.9;
import "../lib/Types.sol";
interface IDealer {
    function deposit(
        uint256 primaryAmount,
        uint256 secondaryAmount,
        address to
    ) external;
    function requestWithdraw(uint256 primaryAmount, uint256 secondaryAmount)
        external;
    function executeWithdraw(address to, bool isInternal) external;
    function approveTrade(address orderSender, bytes calldata tradeData)
        external
        returns (
            address[] memory traderList,
            int256[] memory paperChangeList,
            int256[] memory creditChangeList
        );
    function isSafe(address trader) external view returns (bool);
    function isAllSafe(address[] calldata traderList)
        external
        view
        returns (bool);
    function getFundingRate(address perp) external view returns (int256);
    function updateFundingRate(
        address[] calldata perpList,
        int256[] calldata rateList
    ) external;
    function requestLiquidation(
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
        );
    function handleBadDebt(address liquidatedTrader) external;
    function openPosition(address trader) external;
    function realizePnl(address trader, int256 pnl) external;
    function setOperator(address operator, bool isValid) external;
    function getRiskParams(address perp)
        external
        view
        returns (Types.RiskParams memory params);
    function getAllRegisteredPerps() external view returns (address[] memory);
    function getMarkPrice(address perp) external view returns (uint256);
    function getPositions(address trader)
        external
        view
        returns (address[] memory);
    function getCreditOf(address trader)
        external
        view
        returns (
            int256 primaryCredit,
            uint256 secondaryCredit,
            uint256 pendingPrimaryWithdraw,
            uint256 pendingSecondaryWithdraw,
            uint256 executionTimestamp
        );
    function getTraderRisk(address trader)
        external
        view
        returns (
            int256 netValue,
            uint256 exposure,
            uint256 maintenanceMargin
        );
    function getLiquidationPrice(address trader, address perp)
        external
        view
        returns (uint256 liquidationPrice);
    function getLiquidationCost(
        address perp,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        external
        view
        returns (int256 liqtorPaperChange, int256 liqtorCreditChange);
    function getOrderFilledAmount(bytes32 orderHash)
        external
        view
        returns (uint256 filledAmount);
    function isOrderSenderValid(address orderSender)
        external
        view
        returns (bool);
    function isOperatorValid(address client, address operator)
        external
        view
        returns (bool);
}