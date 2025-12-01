pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/IERC20Token.sol";
import "./interfaces/ITokenManager.sol";
import "./utils/Errors.sol";
import "./TokenPairs.sol";
import "./TypeTokens.sol";
contract TokenManager is AccessControl, TypeTokens, TokenPairs, ITokenManager {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    uint256 public constant RESERVE_RATIO_BASE = 1e18;
    uint256 public constant SWAP_FEE_BASE = 1e6;
    mapping(address => uint256) internal _maxPriceTolerance;
    mapping(address => uint256) internal _minPriceTolerance;
    mapping(bytes32 => PairConfig) internal _pair;
    IERC20Token public usd1;
    event PairUpdated(
        bytes32 indexed pairHash,
        address indexed baseToken,
        address indexed quoteToken,
        uint24 buyFee,
        uint232 buyReserveRatioThreshold,
        uint24 sellFee,
        uint232 sellReserveRatioThreshold
    );
    error NotTimelock(address caller);
    modifier onlyTimelock() {
        if (!hasRole(TIMELOCK_ROLE, msg.sender)) {
            revert NotTimelock(msg.sender);
        }
        _;
    }
    constructor(
        address governor_,
        address timelock_,
        address usd1_,
        TokenConfig[] memory tokens_,
        PairConfig[] memory pairs_
    ) {
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(TIMELOCK_ROLE, GOVERNOR_ROLE);
        _grantRole(GOVERNOR_ROLE, governor_);
        _grantRole(TIMELOCK_ROLE, timelock_);
        _setUSD1(usd1_);
        _addTokensAndPairs(tokens_, pairs_);
    }
    function setUSD1(address token) external onlyTimelock {
        _setUSD1(token);
    }
    function setMinMaxPriceTolerance(address token, uint256 minPrice, uint256 maxPrice) external onlyTimelock {
        _setMinMaxPriceTolerance(token, minPrice, maxPrice);
    }
    function addTokensAndPairs(TokenConfig[] calldata tokens, PairConfig[] calldata pairs) external onlyTimelock {
        _addTokensAndPairs(tokens, pairs);
    }
    function removeTokensAndPairs(
        address[] calldata tokens,
        address[] calldata pairTokensX,
        address[] calldata pairTokensY
    ) external onlyTimelock {
        _require(pairTokensX.length == pairTokensY.length, Errors.ARRAY_LENGTH_MISMATCHED);
        uint256 tokenCount = tokens.length;
        uint256 pairCount = pairTokensX.length;
        for (uint256 i; i < pairCount; i++) {
            _removePair(pairTokensX[i], pairTokensY[i]);
        }
        for (uint256 i; i < tokenCount; i++) {
            _removeToken(tokens[i]);
        }
    }
    function updatePairs(PairConfig[] calldata pairs) external onlyTimelock {
        uint256 pairCount = pairs.length;
        for (uint256 i; i < pairCount; i++) {
            _updatePair(pairs[i]);
        }
    }
    function listPairsByIndexAndCount(uint256 index, uint256 count) external view returns (PairConfig[] memory) {
        uint256 pairCount = _pairHashes.length();
        _require(
            (index == 0 || index < pairCount) && index + count <= pairCount,
            Errors.INPUT_OUT_OF_BOUNDS
        );
        PairConfig[] memory pairs = new PairConfig[](count);
        for (uint256 i; i < count; i++) {
            pairs[i] = _pair[_pairHashes.at(index + i)];
        }
        return pairs;
    }
    function getPriceTolerance(address token) public view returns (uint256 minPrice, uint256 maxPrice) {
        minPrice = _minPriceTolerance[token];
        maxPrice = _maxPriceTolerance[token];
    }
    function getTokenType(address token) public view returns (TokenType) {
        return TokenType(_tokenType[token]);
    }
    function getPair(address tokenX, address tokenY) public view returns (PairConfig memory pair) {
        (tokenX, tokenY) = _sortTokens(tokenX, tokenY);
        return _pair[_checkPairExists(tokenX, tokenY)];
    }
    function pairByIndex(uint256 index) public view returns (PairConfig memory pair) {
        return _pair[_pairHashes.at(index)];
    }
    function _setUSD1(address token) internal {
        address oldToken = address(usd1);
        if (oldToken != address(0)) {
            _removeToken(oldToken);
        }
        _addToken(token, uint8(TokenType.Stable));
        usd1 = IERC20Token(token);
    }
    function _setMinMaxPriceTolerance(address token, uint256 minPrice, uint256 maxPrice) internal {
        _require(maxPrice != 0, Errors.MAX_PRICE_INVALID);
        _require(minPrice != 0 && minPrice <= maxPrice, Errors.MIN_PRICE_INVALID);
        _maxPriceTolerance[token] = maxPrice;
        _minPriceTolerance[token] = minPrice;
    }
    function _addTokensAndPairs(TokenConfig[] memory tokens, PairConfig[] memory pairs) internal {
        uint256 tokenCount = tokens.length;
        uint256 pairCount = pairs.length;
        for (uint256 i; i < tokenCount; i++) {
            TokenConfig memory token = tokens[i];
            _addToken(token.token, uint8(token.tokenType));
            _setMinMaxPriceTolerance(token.token, token.minPrice, token.maxPrice);
        }
        for (uint256 i; i < pairCount; i++) {
            _addPair(pairs[i]);
        }
    }
    function _removeToken(address token) internal override {
        _require(pairTokenLength(token) == 0, Errors.PAIRS_MUST_REMOVED);
        super._removeToken(token);
        if (token == address(usd1)) {
            usd1 = IERC20Token(address(0x0));
        }
    }
    function _addPair(PairConfig memory pair) internal {
        _checkPairParameters(pair);
        (address tokenX, address tokenY) = _sortTokens(pair.baseToken, pair.quoteToken);
        bytes32 pairHash = _addPairByTokens(tokenX, tokenY);
        _pair[pairHash] = pair;
        emit PairUpdated(
            pairHash,
            pair.baseToken,
            pair.quoteToken,
            pair.buyFee,
            pair.buyReserveRatioThreshold,
            pair.sellFee,
            pair.sellReserveRatioThreshold
        );
    }
    function _updatePair(PairConfig memory pair) internal {
        _checkPairParameters(pair);
        (address tokenX, address tokenY) = _sortTokens(pair.baseToken, pair.quoteToken);
        bytes32 pairHash = _checkPairExists(tokenX, tokenY);
        _pair[pairHash] = pair;
        emit PairUpdated(
            pairHash,
            pair.baseToken,
            pair.quoteToken,
            pair.buyFee,
            pair.buyReserveRatioThreshold,
            pair.sellFee,
            pair.sellReserveRatioThreshold
        );
    }
    function _removePair(address tokenX, address tokenY) internal {
        (tokenX, tokenY) = _sortTokens(tokenX, tokenY);
        bytes32 pairHash = _removePairByTokens(tokenX, tokenY);
        delete _pair[pairHash];
    }
    function _checkPairParameters(PairConfig memory pair)
        internal
        view
        tokenInPool(pair.baseToken)
        tokenInPool(pair.quoteToken)
    {
        _require(pair.baseToken != pair.quoteToken, Errors.PAIR_INVALID);
        address usd1Address = address(usd1);
        _require(usd1Address != address(0), Errors.USD1_NOT_SET);
        _require(pair.baseToken == usd1Address || pair.quoteToken == usd1Address, Errors.PAIR_INVALID);
        _checkSwapFeeNumerator(pair.buyFee);
        _checkReserveRatioThreshold(pair.buyReserveRatioThreshold);
        _checkSwapFeeNumerator(pair.sellFee);
        _checkReserveRatioThreshold(pair.sellReserveRatioThreshold);
    }
    function _isTokenTypeValid(uint8 tokenType) internal pure override returns (bool) {
        return tokenType == uint8(TokenType.Asset) || tokenType == uint8(TokenType.Stable);
    }
    function _checkSwapFeeNumerator(uint24 feeNumerator) internal pure {
        _require(feeNumerator < SWAP_FEE_BASE, Errors.FEE_NUMERATOR_INVALID);
    }
    function _checkReserveRatioThreshold(uint232 reserveRatioThreshold) internal pure {
        _require(
            reserveRatioThreshold == 0 || reserveRatioThreshold >= RESERVE_RATIO_BASE,
            Errors.RESERVE_RATIO_THRESHOLD_INVALID
        );
    }
}