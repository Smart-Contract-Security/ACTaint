pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./utils/AddressUtils.sol";
import "./utils/Errors.sol";
abstract contract PoolBalances {
    using MathUpgradeable for uint256;
    using SafeERC20 for IERC20;
    mapping(address => uint256) internal _balance;
    mapping(address => uint256) internal _portfolio;
    event BalanceUpdated(address indexed token, uint256 newBalance);
    event PortfolioReceived(address indexed token, address indexed sender, uint256 amount);
    event PortfolioSent(address indexed token, address indexed receiver, uint256 amount);
    event PortfolioUpdated(address indexed token, uint256 newPortfolio);
    function _setBalance(address token, uint256 newBalance) internal virtual {
        _balance[token] = newBalance;
        emit BalanceUpdated(token, newBalance);
    }
    function _setPortfolio(address token, uint256 newPortfolio) internal virtual {
        _portfolio[token] = newPortfolio;
        emit PortfolioUpdated(token, newPortfolio);
    }
    function _receivePortfolio(address token, address sender, uint256 amount) internal virtual {
        AddressUtils.checkNotZero(token);
        AddressUtils.checkNotZero(sender);
        _checkAmountPositive(amount);
        _require(sender != address(this), Errors.SENDER_INVALID);
        uint256 portfolio = _getPortfolio(token);
        _require(amount <= portfolio, Errors.AMOUNT_INVALID);
        _setPortfolio(token, portfolio - amount);
        IERC20(token).safeTransferFrom(sender, address(this), amount);
        emit PortfolioReceived(token, sender, amount);
    }
    function _sendPortfolio(address token, address receiver, uint256 amount) internal virtual {
        AddressUtils.checkNotZero(token);
        AddressUtils.checkNotZero(receiver);
        _checkAmountPositive(amount);
        _require(receiver != address(this), Errors.RECEIVER_INVALID);
        uint256 portfolio = _getPortfolio(token);
        amount = amount.min(_getBalance(token) - portfolio);
        _require(amount > 0, Errors.POOL_BALANCE_INSUFFICIENT);
        _setPortfolio(token, portfolio + amount);
        IERC20(token).safeTransfer(receiver, amount);
        emit PortfolioSent(token, receiver, amount);
    }
    function _getBalance(address token) internal view virtual returns (uint256) {
        return _balance[token];
    }
    function _getPortfolio(address token) internal view virtual returns (uint256) {
        return _portfolio[token];
    }
    function _checkAmountPositive(uint256 amount) internal pure {
        _require(amount > 0, Errors.AMOUNT_INVALID);
    }
    uint256[48] private __gap;
}