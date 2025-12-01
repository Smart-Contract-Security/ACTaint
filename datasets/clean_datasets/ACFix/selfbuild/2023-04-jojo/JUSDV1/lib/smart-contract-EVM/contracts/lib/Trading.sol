pragma solidity 0.8.9;
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../intf/IPerpetual.sol";
import "../intf/IMarkPriceSource.sol";
import "../utils/SignedDecimalMath.sol";
import "../utils/Errors.sol";
import "./EIP712.sol";
import "./Types.sol";
import "./Liquidation.sol";
import "./Position.sol";
library Trading {
    using SignedDecimalMath for int256;
    using Math for uint256;
    event OrderFilled(
        bytes32 indexed orderHash,
        address indexed trader,
        address indexed perp,
        int256 orderFilledPaperAmount,
        int256 filledCreditAmount,
        uint256 positionSerialNum
    );
    function _matchOrders(
        Types.State storage state,
        bytes32[] memory orderHashList,
        Types.Order[] memory orderList,
        uint256[] memory matchPaperAmount
    ) internal returns (Types.MatchResult memory result) {
        {
            require(orderList.length >= 2, Errors.INVALID_TRADER_NUMBER);
            uint256 uniqueTraderNum = 2;
            uint256 totalMakerFilledPaper = matchPaperAmount[1];
            for (uint256 i = 2; i < orderList.length;) {
                totalMakerFilledPaper += matchPaperAmount[i];
                if (orderList[i].signer > orderList[i - 1].signer) {
                    uniqueTraderNum = uniqueTraderNum + 1;
                } else {
                    require(
                        orderList[i].signer == orderList[i - 1].signer,
                        Errors.ORDER_WRONG_SORTING
                    );
                }
                unchecked {
                    ++i;
                }
            }
            require(
                matchPaperAmount[0] == totalMakerFilledPaper,
                Errors.TAKER_TRADE_AMOUNT_WRONG
            );
            result.traderList = new address[](uniqueTraderNum);
            result.traderList[0] = orderList[0].signer;
        }
        result.paperChangeList = new int256[](result.traderList.length);
        result.creditChangeList = new int256[](result.traderList.length);
        {
            uint256 currentTraderIndex = 1;
            result.traderList[1] = orderList[1].signer;
            for (uint256 i = 1; i < orderList.length; ) {
                _priceMatchCheck(orderList[0], orderList[i]);
                if (i >= 2 && orderList[i].signer != orderList[i - 1].signer) {
                    currentTraderIndex = currentTraderIndex + 1;
                    result.traderList[currentTraderIndex] = orderList[i].signer;
                }
                int256 paperChange = orderList[i].paperAmount > 0
                    ? SafeCast.toInt256(matchPaperAmount[i])
                    : -1 * SafeCast.toInt256(matchPaperAmount[i]);
                int256 creditChange = (paperChange *
                    orderList[i].creditAmount) / orderList[i].paperAmount;
                int256 fee = SafeCast.toInt256(creditChange.abs()).decimalMul(
                    _info2MakerFeeRate(orderList[i].info)
                );
                uint256 serialNum = state.positionSerialNum[
                    orderList[i].signer
                ][msg.sender];
                emit OrderFilled(
                    orderHashList[i],
                    orderList[i].signer,
                    msg.sender,
                    paperChange,
                    creditChange - fee,
                    serialNum
                );
                result.paperChangeList[currentTraderIndex] += paperChange;
                result.creditChangeList[currentTraderIndex] += creditChange - fee;
                result.paperChangeList[0] -= paperChange;
                result.creditChangeList[0] -= creditChange;
                result.orderSenderFee += fee;
                unchecked {
                    ++i;
                }
            }
        }
        {
            int256 takerFee = SafeCast.toInt256(result.creditChangeList[0].abs())
                .decimalMul(_info2TakerFeeRate(orderList[0].info));
            result.creditChangeList[0] -= takerFee;
            result.orderSenderFee += takerFee;
            emit OrderFilled(
                orderHashList[0],
                orderList[0].signer,
                msg.sender,
                result.paperChangeList[0],
                result.creditChangeList[0],
                state.positionSerialNum[orderList[0].signer][msg.sender]
            );
        }
    }
    function _priceMatchCheck(
        Types.Order memory takerOrder,
        Types.Order memory makerOrder
    ) private pure {
        int256 temp1 = int256(makerOrder.creditAmount) *
            int256(takerOrder.paperAmount);
        int256 temp2 = int256(takerOrder.creditAmount) *
            int256(makerOrder.paperAmount);
        if (takerOrder.paperAmount > 0) {
            require(makerOrder.paperAmount < 0, Errors.ORDER_PRICE_NOT_MATCH);
            require(temp1 <= temp2, Errors.ORDER_PRICE_NOT_MATCH);
        } else {
            require(makerOrder.paperAmount > 0, Errors.ORDER_PRICE_NOT_MATCH);
            require(temp1 >= temp2, Errors.ORDER_PRICE_NOT_MATCH);
        }
    }
    function _structHash(Types.Order memory order)
        internal
        pure
        returns (bytes32 structHash)
    {
        bytes32 orderTypeHash = Types.ORDER_TYPEHASH;
        assembly {
            let start := sub(order, 32)
            let tmp := mload(start)
            mstore(start, orderTypeHash)
            structHash := keccak256(start, 192)
            mstore(start, tmp)
        }
    }
    function _info2MakerFeeRate(bytes32 info) internal pure returns (int256) {
        bytes8 value = bytes8(info >> 192);
        int64 makerFee;
        assembly {
            makerFee := value
        }
        return int256(makerFee);
    }
    function _info2TakerFeeRate(bytes32 info)
        internal
        pure
        returns (int256 takerFeeRate)
    {
        bytes8 value = bytes8(info >> 128);
        int64 takerFee;
        assembly {
            takerFee := value
        }
        return int256(takerFee);
    }
    function _info2Expiration(bytes32 info) internal pure returns (uint256) {
        bytes8 value = bytes8(info >> 64);
        uint64 expiration;
        assembly {
            expiration := value
        }
        return uint256(expiration);
    }
}