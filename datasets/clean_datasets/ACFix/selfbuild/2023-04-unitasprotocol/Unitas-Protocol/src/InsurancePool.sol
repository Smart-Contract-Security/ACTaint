pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IInsurancePool.sol";
import "../src/utils/Errors.sol";
import "./PoolBalances.sol";
contract InsurancePool is AccessControl, ReentrancyGuard, IInsurancePool, PoolBalances {
    using SafeERC20 for IERC20;
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    bytes32 public constant PORTFOLIO_ROLE = keccak256("PORTFOLIO_ROLE");
    event CollateralDeposited(address indexed token, address indexed sender, uint256 amount);
    event CollateralWithdrawn(address indexed token, address indexed receiver, uint256 amount);
    error NotGuardian(address caller);
    error NotWithdrawer(address caller);
    error NotTimelock(address caller);
    error NotPortfolio(address caller);
    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender))
            revert NotGuardian(msg.sender);
        _;
    }
    modifier onlyGuardianOrWithdrawer() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender) && !hasRole(WITHDRAWER_ROLE, msg.sender))
            revert NotWithdrawer(msg.sender);
        _;
    }
    modifier onlyTimelock() {
        if (!hasRole(TIMELOCK_ROLE, msg.sender))
            revert NotTimelock(msg.sender);
        _;
    }
    modifier onlyPortfolio(address account) {
        if (!hasRole(PORTFOLIO_ROLE, account)) {
            revert NotPortfolio(account);
        }
        _;
    }
    constructor(address governor_, address guardian_, address timelock_) {
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(WITHDRAWER_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(TIMELOCK_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(PORTFOLIO_ROLE, GUARDIAN_ROLE);
        _grantRole(GOVERNOR_ROLE, governor_);
        _grantRole(GUARDIAN_ROLE, guardian_);
        _grantRole(TIMELOCK_ROLE, timelock_);
        _grantRole(PORTFOLIO_ROLE, guardian_);
    }
    function depositCollateral(address token, uint256 amount) external onlyGuardian nonReentrant {
        _checkAmountPositive(amount);
        _setBalance(token, _getBalance(token) + amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit CollateralDeposited(token, msg.sender, amount);
    }
    function withdrawCollateral(address token, uint256 amount) external onlyGuardianOrWithdrawer nonReentrant {
        _checkAmountPositive(amount);
        uint256 collateral = _getBalance(token);
        _require(collateral - _getPortfolio(token) >= amount, Errors.POOL_BALANCE_INSUFFICIENT);
        _setBalance(token, collateral - amount);
        IERC20(token).safeTransfer(msg.sender, amount);
        emit CollateralWithdrawn(token, msg.sender, amount);
    }
    function receivePortfolio(address token, uint256 amount)
        external
        onlyPortfolio(msg.sender)
        nonReentrant
    {
        _receivePortfolio(token, msg.sender, amount);
    }
    function sendPortfolio(address token, address receiver, uint256 amount)
        external
        onlyTimelock
        onlyPortfolio(receiver)
        nonReentrant
    {
        _sendPortfolio(token, receiver, amount);
    }
    function getCollateral(address token) public view returns (uint256) {
        return _getBalance(token);
    }
    function getPortfolio(address token) public view returns (uint256) {
        return _getPortfolio(token);
    }
}