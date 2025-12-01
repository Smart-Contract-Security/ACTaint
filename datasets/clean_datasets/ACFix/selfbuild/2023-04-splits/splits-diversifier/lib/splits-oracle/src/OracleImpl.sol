pragma solidity ^0.8.17;
import {OwnableImpl} from "splits-utils/OwnableImpl.sol";
import {PausableImpl} from "splits-utils/PausableImpl.sol";
import {QuotePair} from "./utils/QuotePair.sol";
abstract contract OracleImpl is PausableImpl {
    struct QuoteParams {
        QuotePair quotePair;
        uint128 baseAmount;
        bytes data;
    }
    function getQuoteAmounts(QuoteParams[] calldata quoteParams_) external view virtual returns (uint256[] memory);
}