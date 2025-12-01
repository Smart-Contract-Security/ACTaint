pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "./interfaces/IERC20Token.sol";
import "./interfaces/IInsurancePool.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUnitas.sol";
import "./utils/AddressUtils.sol";
import "./utils/Errors.sol";
import "./utils/ScalingUtils.sol";
import "./SwapFunctions.sol";
import "./PoolBalances.sol";
contract Unitas is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IUnitas,
    PoolBalances,
    SwapFunctions
{
    using MathUpgradeable for uint256;
    using SafeERC20 for IERC20;
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    bytes32 public constant PORTFOLIO_ROLE = keccak256("PORTFOLIO_ROLE");
    IOracle public oracle;
    address public surplusPool;
    address public insurancePool;
    ITokenManager public tokenManager;
    event SetOracle(address indexed newOracle);
    event SetSurplusPool(address indexed newSurplusPool);
    event SetInsurancePool(address indexed newInsurancePool);
    event SetTokenManager(ITokenManager indexed newTokenManager);
    event Swapped(
        address indexed tokenIn,
        address indexed tokenOut,
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address feeToken,
        uint256 fee,
        uint24 feeNumerator,
        uint256 price
    );
    event SwapFeeSent(address indexed feeToken, address indexed receiver, uint256 fee);
    error NotTimelock(address caller);
    error NotGuardian(address caller);
    error NotPortfolio(address caller);
    modifier onlyTimelock() {
        if (!hasRole(TIMELOCK_ROLE, msg.sender))
            revert NotTimelock(msg.sender);
        _;
    }
    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender))
            revert NotGuardian(msg.sender);
        _;
    }
    modifier onlyPortfolio(address account) {
        if (!hasRole(PORTFOLIO_ROLE, account)) {
            revert NotPortfolio(account);
        }
        _;
    }
    constructor() {
        _disableInitializers();
    }
    function initialize(InitializeConfig calldata config_) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(TIMELOCK_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(PORTFOLIO_ROLE, GUARDIAN_ROLE);
        _grantRole(GOVERNOR_ROLE, config_.governor);
        _grantRole(GUARDIAN_ROLE, config_.guardian);
        _grantRole(TIMELOCK_ROLE, config_.timelock);
        _grantRole(PORTFOLIO_ROLE, config_.guardian);
        _setOracle(config_.oracle);
        _setSurplusPool(config_.surplusPool);
        _setInsurancePool(config_.insurancePool);
        _setTokenManager(config_.tokenManager);
    }
    function setOracle(address newOracle) external onlyTimelock {
        _setOracle(newOracle);
    }
    function setSurplusPool(address newSurplusPool) external onlyTimelock {
        _setSurplusPool(newSurplusPool);
    }
    function setInsurancePool(address newInsurancePool) external onlyTimelock {
        _setInsurancePool(newInsurancePool);
    }
    function setTokenManager(ITokenManager newTokenManager) external onlyTimelock {
        _setTokenManager(newTokenManager);
    }
    function pause() public onlyGuardian {
        _pause();
    }
    function unpause() public onlyGuardian {
        _unpause();
    }
    function swap(address tokenIn, address tokenOut, AmountType amountType, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 amountIn, uint256 amountOut)
    {
        IERC20Token feeToken;
        uint256 fee;
        uint24 feeNumerator;
        uint256 price;
        ITokenManager.PairConfig memory pair = tokenManager.getPair(tokenIn, tokenOut);
        (amountIn, amountOut, feeToken, fee, feeNumerator, price) = _getSwapResult(pair, tokenIn, tokenOut, amountType, amount);
        _require(IERC20(tokenIn).balanceOf(msg.sender) >= amountIn, Errors.BALANCE_INSUFFICIENT);
        _swapIn(tokenIn, msg.sender, amountIn);
        _swapOut(tokenOut, msg.sender, amountOut);
        if (fee > 0) {
            address feeReceiver = surplusPool;
            feeToken.mint(feeReceiver, fee);
            emit SwapFeeSent(address(feeToken), feeReceiver, fee);
        }
        _checkReserveRatio(tokenOut == pair.baseToken ? pair.buyReserveRatioThreshold : pair.sellReserveRatioThreshold);
        emit Swapped(tokenIn, tokenOut, msg.sender, amountIn, amountOut, address(feeToken), fee, feeNumerator, price);
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
    function estimateSwapResult(address tokenIn, address tokenOut, AmountType amountType, uint256 amount)
        external
        view
        returns (uint256 amountIn, uint256 amountOut, IERC20Token feeToken, uint256 fee, uint24 feeNumerator, uint256 price)
    {
        ITokenManager.PairConfig memory pair = tokenManager.getPair(tokenIn, tokenOut);
        (amountIn, amountOut, feeToken, fee, feeNumerator, price) = _getSwapResult(pair, tokenIn, tokenOut, amountType, amount);
    }
    function getReserve(address token) public view returns (uint256) {
        return _getBalance(token);
    }
    function getPortfolio(address token) public view returns (uint256) {
        return _getPortfolio(token);
    }
    function getReserveStatus()
        public
        view
        returns (ReserveStatus reserveStatus, uint256 reserves, uint256 collaterals, uint256 liabilities, uint256 reserveRatio)
    {
        (reserves, collaterals) = _getTotalReservesAndCollaterals();
        liabilities = _getTotalLiabilities();
        (reserveStatus, reserveRatio) = _getReserveStatus(reserves + collaterals, liabilities);
    }
    function _setOracle(address newOracle) internal {
        AddressUtils.checkContract(newOracle);
        oracle = IOracle(newOracle);
        emit SetOracle(newOracle);
    }
    function _setSurplusPool(address newSurplusPool) internal {
        _require(newSurplusPool != address(0), Errors.ADDRESS_ZERO);
        surplusPool = newSurplusPool;
        emit SetSurplusPool(newSurplusPool);
    }
    function _setInsurancePool(address newInsurancePool) internal {
        AddressUtils.checkContract(newInsurancePool);
        insurancePool = newInsurancePool;
        emit SetInsurancePool(newInsurancePool);
    }
    function _setTokenManager(ITokenManager newTokenManager) internal {
        AddressUtils.checkContract(address(newTokenManager));
        tokenManager = newTokenManager;
        emit SetTokenManager(newTokenManager);
    }
    function _swapIn(address token, address spender, uint256 amount) internal {
        ITokenManager.TokenType tokenType = tokenManager.getTokenType(token);
        require(tokenType != ITokenManager.TokenType.Undefined);
        if (tokenType == ITokenManager.TokenType.Asset) {
            _setBalance(token, _getBalance(token) + amount);
            IERC20(token).safeTransferFrom(spender, address(this), amount);
        } else {
            IERC20Token(token).burn(spender, amount);
        }
    }
    function _swapOut(address token, address receiver, uint256 amount) internal {
        ITokenManager.TokenType tokenType = tokenManager.getTokenType(token);
        require(tokenType != ITokenManager.TokenType.Undefined);
        if (tokenType == ITokenManager.TokenType.Asset) {
            uint256 tokenReserve = _getBalance(token);
            uint256 reserveAmount = amount.min(tokenReserve - _getPortfolio(token));
            if (amount > reserveAmount) {
                uint256 collateralAmount = amount - reserveAmount;
                IInsurancePool(insurancePool).withdrawCollateral(token, collateralAmount);
            }
            _setBalance(token, tokenReserve - reserveAmount);
            IERC20(token).safeTransfer(receiver, amount);
        } else {
            IERC20Token(token).mint(receiver, amount);
        }
    }
    function _getSwapResult(
        ITokenManager.PairConfig memory pair,
        address tokenIn,
        address tokenOut,
        AmountType amountType,
        uint256 amount
    )
        internal
        view
        returns (uint256 amountIn, uint256 amountOut, IERC20Token feeToken, uint256 fee, uint24 feeNumerator, uint256 price)
    {
        _checkAmountPositive(amount);
        bool isBuy = tokenOut == pair.baseToken;
        _require(
            (isBuy && tokenIn == pair.quoteToken) ||
                (tokenOut == pair.quoteToken && tokenIn == pair.baseToken),
            Errors.PAIR_INVALID
        );
        address priceQuoteToken = _getPriceQuoteToken(tokenIn, tokenOut);
        price = oracle.getLatestPrice(priceQuoteToken);
        _checkPrice(priceQuoteToken, price);
        feeNumerator = isBuy ? pair.buyFee : pair.sellFee;
        feeToken = IERC20Token(priceQuoteToken == tokenIn ? tokenOut : tokenIn);
        SwapRequest memory request;
        request.tokenIn = tokenIn;
        request.tokenOut = tokenOut;
        request.amountType = amountType;
        request.amount = amount;
        request.feeNumerator = feeNumerator;
        request.feeBase = tokenManager.SWAP_FEE_BASE();
        request.feeToken = address(feeToken);
        request.price = price;
        request.priceBase = 10 ** oracle.decimals();
        request.quoteToken = priceQuoteToken;
        (amountIn, amountOut, fee) = _calculateSwapResult(request);
        _require(amountIn > 0 && amountOut > 0, Errors.SWAP_RESULT_INVALID);
        if (tokenIn == priceQuoteToken) {
            price = request.priceBase * request.priceBase / price;
        }
    }
    function _getReserveStatus(uint256 allReserves, uint256 liabilities)
        internal
        view
        returns (ReserveStatus reserveStatus, uint256 reserveRatio)
    {
        if (liabilities == 0) {
            reserveStatus = allReserves == 0 ? ReserveStatus.Undefined : ReserveStatus.Infinite;
        } else {
            reserveStatus = ReserveStatus.Finite;
            uint256 valueBase = 10 ** tokenManager.usd1().decimals();
            reserveRatio = ScalingUtils.scaleByBases(
                allReserves * valueBase / liabilities,
                valueBase,
                tokenManager.RESERVE_RATIO_BASE()
            );
        }
    }
    function _getTotalReservesAndCollaterals() internal view returns (uint256 reserves, uint256 collaterals) {
        address baseToken = address(tokenManager.usd1());
        uint8 tokenTypeValue = uint8(ITokenManager.TokenType.Asset);
        uint256 tokenCount = tokenManager.tokenLength(tokenTypeValue);
        uint256 priceBase = 10 ** oracle.decimals();
        for (uint256 i; i < tokenCount; i++) {
            address token = tokenManager.tokenByIndex(tokenTypeValue, i);
            uint256 tokenReserve = _getBalance(token);
            uint256 tokenCollateral = IInsurancePool(insurancePool).getCollateral(token);
            if (tokenReserve > 0 || tokenCollateral > 0) {
                uint256 price = oracle.getLatestPrice(token);
                reserves += _convert(
                    token,
                    baseToken,
                    tokenReserve,
                    MathUpgradeable.Rounding.Down,
                    price,
                    priceBase,
                    token
                );
                collaterals += _convert(
                    token,
                    baseToken,
                    tokenCollateral,
                    MathUpgradeable.Rounding.Down,
                    price,
                    priceBase,
                    token
                );
            }
        }
    }
    function _getTotalLiabilities() internal view returns (uint256 liabilities) {
        address baseToken = address(tokenManager.usd1());
        uint8 tokenTypeValue = uint8(ITokenManager.TokenType.Stable);
        uint256 tokenCount = tokenManager.tokenLength(tokenTypeValue);
        uint256 priceBase = 10 ** oracle.decimals();
        for (uint256 i; i < tokenCount; i++) {
            address token = tokenManager.tokenByIndex(tokenTypeValue, i);
            uint256 tokenSupply = IERC20Token(token).totalSupply();
            if (token == baseToken) {
                liabilities += tokenSupply;
            } else if (tokenSupply > 0) {
                uint256 price = oracle.getLatestPrice(token);
                liabilities += _convert(
                    token,
                    baseToken,
                    tokenSupply,
                    MathUpgradeable.Rounding.Down,
                    price,
                    priceBase,
                    token
                );
            }
        }
    }
    function _getPriceQuoteToken(address tokenX, address tokenY) internal view returns (address quoteToken) {
        _require(tokenX != tokenY, Errors.PAIR_INVALID);
        address baseToken = address(tokenManager.usd1());
        _require(baseToken != address(0), Errors.USD1_NOT_SET);
        bool isXBase = tokenX == baseToken;
        _require(isXBase || tokenY == baseToken, Errors.PAIR_INVALID);
        quoteToken = isXBase ? tokenY : tokenX;
    }
    function _checkPrice(address quoteToken, uint256 price) internal view {
        (uint256 minPrice, uint256 maxPrice) = tokenManager.getPriceTolerance(quoteToken);
        _require(minPrice > 0 && maxPrice > 0, Errors.PRICE_TOLERANCE_INVALID);
        _require(minPrice <= price && price <= maxPrice, Errors.PRICE_INVALID);
    }
    function _checkReserveRatio(uint232 reserveRatioThreshold) internal view {
        if (reserveRatioThreshold == 0) {
            return;
        } else {
            (uint256 reserves, uint256 collaterals) = _getTotalReservesAndCollaterals();
            uint256 allReserves = reserves + collaterals;
            uint256 liabilities = _getTotalLiabilities();
            (ReserveStatus reserveStatus, uint256 reserveRatio) = _getReserveStatus(allReserves, liabilities);
            if (reserveStatus != ReserveStatus.Infinite) {
                _require(reserveRatio > reserveRatioThreshold, Errors.RESERVE_RATIO_NOT_GREATER_THAN_THRESHOLD);
            }
        }
    }
}