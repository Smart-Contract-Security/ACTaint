pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./JOJOStorage.sol";
import "../utils/Errors.sol";
import "../utils/SignedDecimalMath.sol";
import "../intf/IDealer.sol";
import "../lib/Liquidation.sol";
import "../lib/Funding.sol";
import "../lib/Trading.sol";
import "../lib/Position.sol";
import "../lib/Operation.sol";
abstract contract JOJOExternal is JOJOStorage, IDealer {
    using SignedDecimalMath for int256;
    using SafeERC20 for IERC20;
    function deposit(
        uint256 primaryAmount,
        uint256 secondaryAmount,
        address to
    ) external nonReentrant {
        Funding.deposit(state, primaryAmount, secondaryAmount, to);
    }
    function requestWithdraw(uint256 primaryAmount, uint256 secondaryAmount)
        external
        nonReentrant
    {
        Funding.requestWithdraw(state, primaryAmount, secondaryAmount);
    }
    function executeWithdraw(address to, bool isInternal)
        external
        nonReentrant
    {
        Funding.executeWithdraw(state, to, isInternal);
    }
    function setOperator(address operator, bool isValid) external {
        Operation.setOperator(state, msg.sender, operator, isValid);
    }
    function handleBadDebt(address liquidatedTrader) external {
        Liquidation.handleBadDebt(state, liquidatedTrader);
    }
    function requestLiquidation(
        address executor,
        address liquidator,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        external
        onlyRegisteredPerp
        returns (
            int256 liqtorPaperChange,
            int256 liqtorCreditChange,
            int256 liqedPaperChange,
            int256 liqedCreditChange
        )
    {
        return
            Liquidation.requestLiquidation(
                state,
                msg.sender,
                executor,
                liquidator,
                liquidatedTrader,
                requestPaperAmount
            );
    }
    function openPosition(address trader) external onlyRegisteredPerp {
        Position._openPosition(state, trader);
    }
    function realizePnl(address trader, int256 pnl)
        external
        onlyRegisteredPerp
    {
        Position._realizePnl(state, trader, pnl);
    }
    function approveTrade(address orderSender, bytes calldata tradeData)
        external
        onlyRegisteredPerp
        returns (
            address[] memory, 
            int256[] memory, 
            int256[] memory 
        )
    {
        require(
            state.validOrderSender[orderSender],
            Errors.INVALID_ORDER_SENDER
        );
        (
            Types.Order[] memory orderList,
            bytes[] memory signatureList,
            uint256[] memory matchPaperAmount
        ) = abi.decode(tradeData, (Types.Order[], bytes[], uint256[]));
        bytes32[] memory orderHashList = new bytes32[](orderList.length);
        for (uint256 i = 0; i < orderList.length; ) {
            Types.Order memory order = orderList[i];
            bytes32 orderHash = EIP712._hashTypedDataV4(
                domainSeparator,
                Trading._structHash(order)
            );
            orderHashList[i] = orderHash;
            address recoverSigner = ECDSA.recover(orderHash, signatureList[i]);
            require(
                recoverSigner == order.signer ||
                    state.operatorRegistry[order.signer][recoverSigner],
                Errors.INVALID_ORDER_SIGNATURE
            );
            require(
                Trading._info2Expiration(order.info) >= block.timestamp,
                Errors.ORDER_EXPIRED
            );
            require(
                (order.paperAmount < 0 && order.creditAmount > 0) ||
                    (order.paperAmount > 0 && order.creditAmount < 0),
                Errors.ORDER_PRICE_NEGATIVE
            );
            require(order.perp == msg.sender, Errors.PERP_MISMATCH);
            require(
                i == 0 || order.signer != orderList[0].signer,
                Errors.ORDER_SELF_MATCH
            );
            state.orderFilledPaperAmount[orderHash] += matchPaperAmount[i];
            require(
                state.orderFilledPaperAmount[orderHash] <=
                    int256(orderList[i].paperAmount).abs(),
                Errors.ORDER_FILLED_OVERFLOW
            );
            unchecked {
                ++i;
            }
        }
        Types.MatchResult memory result = Trading._matchOrders(
            state,
            orderHashList,
            orderList,
            matchPaperAmount
        );
        state.primaryCredit[orderSender] += result.orderSenderFee;
        if (result.orderSenderFee < 0) {
            require(
                Liquidation._isSolidSafe(state, orderSender),
                Errors.ORDER_SENDER_NOT_SAFE
            );
        }
        return (
            result.traderList,
            result.paperChangeList,
            result.creditChangeList
        );
    }
}