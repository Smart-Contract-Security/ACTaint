pragma solidity 0.8.17;
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {NotionalProxy} from "../../interfaces/notional/NotionalProxy.sol";
import {IWrappedfCashFactory} from "../../interfaces/notional/IWrappedfCashFactory.sol";
import {WETH9} from "../../interfaces/WETH9.sol";
import {IWrappedfCashComplete as IWrappedfCash} from "../../interfaces/notional/IWrappedfCash.sol";
import {BaseStrategyVault} from "./BaseStrategyVault.sol";
import {IERC20} from "../utils/TokenUtils.sol";
import {
    AccountContext,
    BalanceActionWithTrades,
    DepositActionType,
    TradeActionType,
    BatchLend,
    Token,
    TokenType,
    VaultState
} from "../global/Types.sol";
import {Constants} from "../global/Constants.sol";
import {DateTime} from "../global/DateTime.sol";
import {TypeConvert} from "../global/TypeConvert.sol";
import {ITradingModule, DexId, TradeType, Trade} from "../../interfaces/trading/ITradingModule.sol";
import {TradeHandler} from "../trading/TradeHandler.sol";
contract CrossCurrencyfCashVault is BaseStrategyVault {
    using TypeConvert for uint256;
    using TypeConvert for int256;
    uint256 public constant SETTLEMENT_SLIPPAGE_PRECISION = 1e18;
    struct DepositParams {
        uint256 minPurchaseAmount;
        uint32 minLendRate;
        uint16 dexId;
        bytes exchangeData;
    }
    struct RedeemParams {
        uint256 minPurchaseAmount;
        uint32 maxBorrowRate;
        uint16 dexId;
        bytes exchangeData;
    }
    uint16 public LEND_CURRENCY_ID;
    IERC20 public LEND_UNDERLYING_TOKEN;
    uint64 public settlementSlippageLimit;
    constructor(NotionalProxy notional_, ITradingModule tradingModule_)
        BaseStrategyVault(notional_, tradingModule_) {}
    function strategy() external override view returns (bytes4) {
        return bytes4(keccak256("CrossCurrencyfCash"));
    }
    function initialize(
        string memory name_,
        uint16 borrowCurrencyId_,
        uint16 lendCurrencyId_,
        uint64 settlementSlippageLimit_
    ) external initializer {
        __INIT_VAULT(name_, borrowCurrencyId_);
        LEND_CURRENCY_ID = lendCurrencyId_;
        (
            Token memory assetToken,
            Token memory underlyingToken,
            ,
        ) = NOTIONAL.getCurrencyAndRates(lendCurrencyId_);
        IERC20 tokenAddress = assetToken.tokenType == TokenType.NonMintable ?
            IERC20(assetToken.tokenAddress) : IERC20(underlyingToken.tokenAddress);
        LEND_UNDERLYING_TOKEN = tokenAddress;
        tokenAddress.approve(address(NOTIONAL), type(uint256).max);
        require(settlementSlippageLimit_ < SETTLEMENT_SLIPPAGE_PRECISION);
        settlementSlippageLimit = settlementSlippageLimit_;
    }
    function updateSettlementSlippageLimit(uint64 newSlippageLimit) external {
        require(msg.sender == NOTIONAL.owner());
        require(newSlippageLimit < SETTLEMENT_SLIPPAGE_PRECISION);
        settlementSlippageLimit = newSlippageLimit;
    }
    function settleVault(uint256 maturity, uint256 strategyTokens, bytes calldata settlementTrade) external {
        require(maturity <= block.timestamp, "Cannot Settle");
        VaultState memory vaultState = NOTIONAL.getVaultState(address(this), maturity);
        require(vaultState.isSettled == false);
        require(vaultState.totalStrategyTokens >= strategyTokens);
        RedeemParams memory params = abi.decode(settlementTrade, (RedeemParams));
        uint256 underlyingValue = convertStrategyToUnderlying(
            address(0), vaultState.totalStrategyTokens, maturity
        ).toUint();
        uint256 minAllowedPurchaseAmount = (underlyingValue * settlementSlippageLimit) / SETTLEMENT_SLIPPAGE_PRECISION;
        require(params.minPurchaseAmount >= minAllowedPurchaseAmount, "Purchase Limit");
        NOTIONAL.redeemStrategyTokensToCash(maturity, strategyTokens, settlementTrade);
        vaultState = NOTIONAL.getVaultState(address(this), maturity);
        if (vaultState.totalStrategyTokens == 0) {
            NOTIONAL.settleVault(address(this), maturity);
        }
    }
    function convertStrategyToUnderlying(
        address ,
        uint256 strategyTokens,
        uint256 maturity
    ) public override view returns (int256 underlyingValue) {
        int256 pvInternal;
        if (maturity <= block.timestamp) {
            pvInternal = strategyTokens.toInt();
        } else {
            pvInternal = NOTIONAL.getPresentfCashValue(
                LEND_CURRENCY_ID, maturity, strategyTokens.toInt(), block.timestamp, false
            );
        }
        IERC20 underlyingToken = _underlyingToken();
        (int256 rate, int256 rateDecimals) = TRADING_MODULE.getOraclePrice(
            address(LEND_UNDERLYING_TOKEN), address(underlyingToken)
        );
        int256 borrowTokenDecimals = int256(10**underlyingToken.decimals());
        return (pvInternal * borrowTokenDecimals * rate) /
            (rateDecimals * int256(Constants.INTERNAL_TOKEN_PRECISION));
    }
    function _depositFromNotional(
        address ,
        uint256 depositUnderlyingExternal,
        uint256 maturity,
        bytes calldata data
    ) internal override returns (uint256 lendfCashMinted) {
        DepositParams memory params = abi.decode(data, (DepositParams));
        Trade memory trade = Trade({
            tradeType: TradeType.EXACT_IN_SINGLE,
            sellToken: address(_underlyingToken()),
            buyToken: address(LEND_UNDERLYING_TOKEN),
            amount: depositUnderlyingExternal,
            limit: params.minPurchaseAmount,
            deadline: block.timestamp,
            exchangeData: params.exchangeData
        });
        (, uint256 lendUnderlyingTokens) = _executeTrade(params.dexId, trade);
        (uint256 fCashAmount, , bytes32 encodedTrade) = NOTIONAL.getfCashLendFromDeposit(
            LEND_CURRENCY_ID,
            lendUnderlyingTokens,
            maturity,
            params.minLendRate,
            block.timestamp,
            true 
        );
        BatchLend[] memory action = new BatchLend[](1);
        action[0].currencyId = LEND_CURRENCY_ID;
        action[0].depositUnderlying = true;
        action[0].trades = new bytes32[](1);
        action[0].trades[0] = encodedTrade;
        NOTIONAL.batchLend(address(this), action);
        return fCashAmount;
    }
    function _redeemFromNotional(
        address account,
        uint256 strategyTokens,
        uint256 maturity,
        bytes calldata data
    ) internal override returns (uint256 borrowedCurrencyAmount) {
        uint256 balanceBefore = LEND_UNDERLYING_TOKEN.balanceOf(address(this));
        RedeemParams memory params = abi.decode(data, (RedeemParams));
        if (maturity <= block.timestamp) {
            require(account == address(this));
            NOTIONAL.settleAccount(address(this));
            (int256 cashBalance, , ) = NOTIONAL.getAccountBalance(LEND_CURRENCY_ID, address(this));
            require(0 <= cashBalance && cashBalance <= int256(uint256(type(uint88).max)));
            NOTIONAL.withdraw(LEND_CURRENCY_ID, uint88(uint256(cashBalance)), true);
        } else {
            BalanceActionWithTrades[] memory action = _encodeBorrowTrade(
                maturity,
                strategyTokens,
                params.maxBorrowRate
            );
            NOTIONAL.batchBalanceAndTradeAction(address(this), action);
            AccountContext memory accountContext = NOTIONAL.getAccountContext(address(this));
            require(accountContext.hasDebt == 0x00);
        }
        uint256 balanceAfter = LEND_UNDERLYING_TOKEN.balanceOf(address(this));
        Trade memory trade = Trade({
            tradeType: TradeType.EXACT_IN_SINGLE,
            sellToken: address(LEND_UNDERLYING_TOKEN),
            buyToken: address(_underlyingToken()),
            amount: balanceAfter - balanceBefore,
            limit: params.minPurchaseAmount,
            deadline: block.timestamp,
            exchangeData: params.exchangeData
        });
        (, borrowedCurrencyAmount) = _executeTrade(params.dexId, trade);
    }
    function _encodeBorrowTrade(
        uint256 maturity,
        uint256 fCashAmount,
        uint32 maxImpliedRate
    ) private view returns (BalanceActionWithTrades[] memory action) {
        (uint256 marketIndex, bool isIdiosyncratic) = DateTime.getMarketIndex(
            Constants.MAX_TRADED_MARKET_INDEX,
            maturity,
            block.timestamp
        );
        require(!isIdiosyncratic);
        require(fCashAmount <= uint256(type(uint88).max));
        action = new BalanceActionWithTrades[](1);
        action[0].actionType = DepositActionType.None;
        action[0].currencyId = LEND_CURRENCY_ID;
        action[0].withdrawEntireCashBalance = true;
        action[0].redeemToUnderlying = true;
        action[0].trades = new bytes32[](1);
        action[0].trades[0] = bytes32(
            (uint256(uint8(TradeActionType.Borrow)) << 248) |
            (uint256(marketIndex) << 240) |
            (uint256(fCashAmount) << 152) |
            (uint256(maxImpliedRate) << 120)
        );
    }
}