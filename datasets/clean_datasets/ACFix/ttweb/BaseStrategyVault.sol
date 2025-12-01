pragma solidity 0.8.17;
import {Token, TokenType} from "../global/Types.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStrategyVault} from "../../interfaces/notional/IStrategyVault.sol";
import {NotionalProxy} from "../../interfaces/notional/NotionalProxy.sol";
import {ITradingModule, Trade} from "../../interfaces/trading/ITradingModule.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {TokenUtils} from "../utils/TokenUtils.sol";
import {TradeHandler} from "../trading/TradeHandler.sol";
import {nProxy} from "../proxy/nProxy.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
abstract contract BaseStrategyVault is Initializable, IStrategyVault, AccessControlUpgradeable {
    using TokenUtils for IERC20;
    using TradeHandler for Trade;
    bytes32 internal constant NORMAL_SETTLEMENT_ROLE = keccak256("NORMAL_SETTLEMENT_ROLE");
    bytes32 internal constant EMERGENCY_SETTLEMENT_ROLE = keccak256("EMERGENCY_SETTLEMENT_ROLE");
    bytes32 internal constant POST_MATURITY_SETTLEMENT_ROLE = keccak256("POST_MATURITY_SETTLEMENT_ROLE");
    bytes32 internal constant REWARD_REINVESTMENT_ROLE = keccak256("REWARD_REINVESTMENT_ROLE");
    NotionalProxy public immutable NOTIONAL;
    ITradingModule public immutable TRADING_MODULE;
    uint8 constant internal INTERNAL_TOKEN_DECIMALS = 8;
    uint16 private _BORROW_CURRENCY_ID;
    bool private _UNDERLYING_IS_ETH;
    IERC20 private _UNDERLYING_TOKEN;
    string private _NAME;
    modifier onlyNotional() {
        require(msg.sender == address(NOTIONAL));
        _;
    }
    modifier onlyNotionalOwner() {
        require(msg.sender == address(NOTIONAL.owner()));
        _;
    }
    constructor(NotionalProxy notional_, ITradingModule tradingModule_) initializer {
        NOTIONAL = notional_;
        TRADING_MODULE = tradingModule_;
    }
    receive() external virtual payable {
    }
    function decimals() public override view returns (uint8) {
        return INTERNAL_TOKEN_DECIMALS;
    }
    function name() external override view returns (string memory) {
        return _NAME;
    }
    function strategy() external virtual view returns (bytes4);
    function _borrowCurrencyId() internal view returns (uint16) {
        return _BORROW_CURRENCY_ID;
    }
    function _underlyingToken() internal view returns (IERC20) {
        return _UNDERLYING_TOKEN;
    }
    function _isUnderlyingETH() internal view returns (bool) {
        return _UNDERLYING_IS_ETH;
    }
    function __INIT_VAULT(
        string memory name_,
        uint16 borrowCurrencyId_
    ) internal onlyInitializing {
        _NAME = name_;
        _BORROW_CURRENCY_ID = borrowCurrencyId_;
        address underlyingAddress = _getNotionalUnderlyingToken(borrowCurrencyId_);
        _UNDERLYING_TOKEN = IERC20(underlyingAddress);
        _UNDERLYING_IS_ETH = underlyingAddress == address(0);
        _setupRole(DEFAULT_ADMIN_ROLE, NOTIONAL.owner());
    }
    function _getNotionalUnderlyingToken(uint16 currencyId) internal view returns (address) {
        (Token memory assetToken, Token memory underlyingToken) = NOTIONAL.getCurrency(currencyId);
        return assetToken.tokenType == TokenType.NonMintable ?
            assetToken.tokenAddress : underlyingToken.tokenAddress;
    }
    function _executeTrade(
        uint16 dexId,
        Trade memory trade
    ) internal returns (uint256 amountSold, uint256 amountBought) {
        return trade._executeTrade(dexId, TRADING_MODULE);
    }
    function convertStrategyToUnderlying(
        address account,
        uint256 strategyTokens,
        uint256 maturity
    ) public view virtual returns (int256 underlyingValue);
    function _depositFromNotional(
        address account,
        uint256 deposit,
        uint256 maturity,
        bytes calldata data
    ) internal virtual returns (uint256 strategyTokensMinted);
    function _redeemFromNotional(
        address account,
        uint256 strategyTokens,
        uint256 maturity,
        bytes calldata data
    ) internal virtual returns (uint256 tokensFromRedeem);
    function _repaySecondaryBorrowCallback(
        address token,  uint256 underlyingRequired, bytes calldata data
    ) internal virtual returns (bytes memory returnData) {
        revert();
    }
    function depositFromNotional(
        address account,
        uint256 deposit,
        uint256 maturity,
        bytes calldata data
    ) external payable onlyNotional returns (uint256 strategyTokensMinted) {
        return _depositFromNotional(account, deposit, maturity, data);
    }
    function redeemFromNotional(
        address account,
        address receiver,
        uint256 strategyTokens,
        uint256 maturity,
        uint256 underlyingToRepayDebt,
        bytes calldata data
    ) external onlyNotional returns (uint256 transferToReceiver) {
        uint256 borrowedCurrencyAmount = _redeemFromNotional(account, strategyTokens, maturity, data);
        uint256 transferToNotional;
        if (account == address(this) || borrowedCurrencyAmount <= underlyingToRepayDebt) {
            transferToNotional = borrowedCurrencyAmount;
        } else {
            transferToNotional = underlyingToRepayDebt;
            unchecked { transferToReceiver = borrowedCurrencyAmount - underlyingToRepayDebt; }
        }
        if (_UNDERLYING_IS_ETH) {
            if (transferToReceiver > 0) payable(receiver).transfer(transferToReceiver);
            if (transferToNotional > 0) payable(address(NOTIONAL)).transfer(transferToNotional);
        } else {
            if (transferToReceiver > 0) _UNDERLYING_TOKEN.checkTransfer(receiver, transferToReceiver);
            if (transferToNotional > 0) _UNDERLYING_TOKEN.checkTransfer(address(NOTIONAL), transferToNotional);
        }
    }
    function repaySecondaryBorrowCallback(
        address token, uint256 underlyingRequired, bytes calldata data
    ) external onlyNotional returns (bytes memory returnData) {
        return _repaySecondaryBorrowCallback(token, underlyingRequired, data);
    }
    function getRoles() external view returns (StrategyVaultRoles memory) {
        return StrategyVaultRoles({
            normalSettlement: NORMAL_SETTLEMENT_ROLE,
            emergencySettlement: EMERGENCY_SETTLEMENT_ROLE,
            postMaturitySettlement: POST_MATURITY_SETTLEMENT_ROLE,
            rewardReinvestment: REWARD_REINVESTMENT_ROLE
        });
    }
    uint256[45] private __gap;
}