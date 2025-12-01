pragma solidity ^0.8.17;
import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "v3-periphery/libraries/OracleLibrary.sol";
import {TokenUtils} from "splits-utils/TokenUtils.sol";
import {OracleImpl} from "./OracleImpl.sol";
import {QuotePair, ConvertedQuotePair, SortedConvertedQuotePair} from "./utils/QuotePair.sol";
contract UniV3OracleImpl is OracleImpl {
    using TokenUtils for address;
    error Pool_DoesNotExist();
    struct InitParams {
        address owner;
        bool paused;
        uint24 defaultFee;
        uint32 defaultPeriod;
        uint32 defaultScaledOfferFactor;
        SetPairOverrideParams[] pairOverrides;
    }
    struct SetPairOverrideParams {
        QuotePair quotePair;
        PairOverride pairOverride;
    }
    struct PairOverride {
        uint24 fee;
        uint32 period;
        uint32 scaledOfferFactor;
    }
    event SetDefaultFee(uint24 defaultFee);
    event SetDefaultPeriod(uint32 defaultPeriod);
    event SetDefaultScaledOfferFactor(uint32 defaultScaledOfferFactor);
    event SetPairOverrides(SetPairOverrideParams[] params);
    uint32 internal constant PERCENTAGE_SCALE = 100_00_00; 
    address public immutable uniV3OracleFactory;
    IUniswapV3Factory public immutable uniswapV3Factory;
    address public immutable weth9;
    uint24 internal $defaultFee;
    uint32 internal $defaultPeriod;
    uint32 internal $defaultScaledOfferFactor;
    mapping(address => mapping(address => PairOverride)) internal $_pairOverrides;
    constructor(IUniswapV3Factory uniswapV3Factory_, address weth9_) {
        uniV3OracleFactory = msg.sender;
        uniswapV3Factory = uniswapV3Factory_;
        weth9 = weth9_;
    }
    function initializer(InitParams calldata params_) external {
        if (msg.sender != uniV3OracleFactory) revert Unauthorized();
        __initOwnable(params_.owner);
        $paused = params_.paused;
        $defaultFee = params_.defaultFee;
        $defaultPeriod = params_.defaultPeriod;
        $defaultScaledOfferFactor = params_.defaultScaledOfferFactor;
        _setPairOverrides(params_.pairOverrides);
    }
    function setDefaultFee(uint24 defaultFee_) external onlyOwner {
        $defaultFee = defaultFee_;
        emit SetDefaultFee(defaultFee_);
    }
    function setDefaultPeriod(uint32 defaultPeriod_) external onlyOwner {
        $defaultPeriod = defaultPeriod_;
        emit SetDefaultPeriod(defaultPeriod_);
    }
    function setDefaultScaledOfferFactor(uint32 defaultScaledOfferFactor_) external onlyOwner {
        $defaultScaledOfferFactor = defaultScaledOfferFactor_;
        emit SetDefaultScaledOfferFactor(defaultScaledOfferFactor_);
    }
    function setPairOverrides(SetPairOverrideParams[] calldata params_) external onlyOwner {
        _setPairOverrides(params_);
        emit SetPairOverrides(params_);
    }
    function defaultFee() external view returns (uint24) {
        return $defaultFee;
    }
    function defaultPeriod() external view returns (uint32) {
        return $defaultPeriod;
    }
    function defaultScaledOfferFactor() external view returns (uint32) {
        return $defaultScaledOfferFactor;
    }
    function getPairOverrides(QuotePair[] calldata quotePairs_)
        external
        view
        returns (PairOverride[] memory pairOverrides)
    {
        uint256 length = quotePairs_.length;
        pairOverrides = new PairOverride[](length);
        for (uint256 i; i < length;) {
            pairOverrides[i] = _getPairOverride(quotePairs_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function getQuoteAmounts(QuoteParams[] calldata quoteParams_)
        external
        view
        override
        pausable
        returns (uint256[] memory quoteAmounts)
    {
        uint256 length = quoteParams_.length;
        quoteAmounts = new uint256[](length);
        for (uint256 i; i < length;) {
            quoteAmounts[i] = _getQuoteAmount(quoteParams_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function _setPairOverrides(SetPairOverrideParams[] calldata params_) internal {
        uint256 length = params_.length;
        for (uint256 i; i < length;) {
            _setPairOverride(params_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function _setPairOverride(SetPairOverrideParams calldata params_) internal {
        SortedConvertedQuotePair memory scqp = _convertAndSortQuotePair(params_.quotePair);
        $_pairOverrides[scqp.cToken0][scqp.cToken1] = params_.pairOverride;
    }
    function _getQuoteAmount(QuoteParams calldata quoteParams_) internal view returns (uint256) {
        ConvertedQuotePair memory cqp = quoteParams_.quotePair._convert(_convertToken);
        SortedConvertedQuotePair memory scqp = cqp._sort();
        PairOverride memory po = _getPairOverride(scqp);
        if (po.scaledOfferFactor == 0) {
            po.scaledOfferFactor = $defaultScaledOfferFactor;
        }
        if (cqp.cBase == cqp.cQuote) {
            return quoteParams_.baseAmount * po.scaledOfferFactor / PERCENTAGE_SCALE;
        }
        if (po.fee == 0) {
            po.fee = $defaultFee;
        }
        if (po.period == 0) {
            po.period = $defaultPeriod;
        }
        address pool = uniswapV3Factory.getPool(scqp.cToken0, scqp.cToken1, po.fee);
        if (pool == address(0)) {
            revert Pool_DoesNotExist();
        }
        (int24 arithmeticMeanTick,) = OracleLibrary.consult({pool: pool, secondsAgo: po.period});
        uint256 unscaledAmountToBeneficiary = OracleLibrary.getQuoteAtTick({
            tick: arithmeticMeanTick,
            baseAmount: quoteParams_.baseAmount,
            baseToken: cqp.cBase,
            quoteToken: cqp.cQuote
        });
        return unscaledAmountToBeneficiary * po.scaledOfferFactor / PERCENTAGE_SCALE;
    }
    function _getPairOverride(QuotePair calldata quotePair_) internal view returns (PairOverride memory) {
        return _getPairOverride(_convertAndSortQuotePair(quotePair_));
    }
    function _getPairOverride(SortedConvertedQuotePair memory scqp_) internal view returns (PairOverride memory) {
        return $_pairOverrides[scqp_.cToken0][scqp_.cToken1];
    }
    function _convertAndSortQuotePair(QuotePair calldata quotePair_)
        internal
        view
        returns (SortedConvertedQuotePair memory)
    {
        return quotePair_._convert(_convertToken)._sort();
    }
    function _convertToken(address token_) internal view returns (address) {
        return token_._isETH() ? weth9 : token_;
    }
}