pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/interfaces/IERC20Token.sol";
import "../src/utils/Errors.sol";
import "../src/ERC20Token.sol";
import "../src/TokenManager.sol";
import "./mocks/MockERC20Token.sol";
import "./utils/Functions.sol";
contract TokenManagerTest is Test {
    IERC20Token internal _usd1;
    IERC20Token internal _usd91;
    IERC20Token internal _usd971;
    MockERC20Token internal _usdt;
    TokenManagerHarness internal _tokenManager;
    address internal immutable _governor = vm.addr(0x1);
    address internal immutable _timelock = vm.addr(0x2);
    event TokenAdded(address indexed token, uint8 tokenType);
    event TokenRemoved(address indexed token, uint8 tokenType);
    event PairAdded(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    event PairRemoved(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    event PairUpdated(
        bytes32 indexed pairHash,
        address indexed baseToken,
        address indexed quoteToken,
        uint24 buyFee,
        uint232 buyReserveRatioThreshold,
        uint24 sellFee,
        uint232 sellReserveRatioThreshold
    );
    function setUp() public virtual {
        _usd1 = _deployUnitasERC20Token("Unitas 1", "USD1");
        _usd91 = _deployUnitasERC20Token("Unitas 91", "USD91");
        _usd971 = _deployUnitasERC20Token("Unitas 971", "USD971");
        _usdt = new MockERC20Token("Tether USD", "USDT", 6);
        _tokenManager = _deployTokenManager();
        vm.label(address(_usd1), "USD1");
        vm.label(address(_usd91), "USD91");
        vm.label(address(_usd971), "USD971");
        vm.label(address(_usdt), "USDT");
    }
    function test_setUSD1_FailWhenNotTimelock() public {
        vm.expectRevert(abi.encodeWithSignature("NotTimelock(address)", address(this)));
        _tokenManager.setUSD1(address(0));
    }
    function test_setUSD1_FailWhenPairsNotEmpty() public {
        IERC20Token newToken = _deployUnitasERC20Token("Unitas 1", "USD1");
        vm.expectRevert(_errorMessage(Errors.PAIRS_MUST_REMOVED));
        vm.prank(_timelock);
        _tokenManager.setUSD1(address(newToken));
    }
    function test_setUSD1_FailWhenAddressZero() public {
        _assertTokenAndPairsRemoved(address(_tokenManager.usd1()));
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        vm.prank(_timelock);
        _tokenManager.setUSD1(address(0x0));
    }
    function test_setUSD1_FailWhenAddressCodeSizeZero() public {
        _assertTokenAndPairsRemoved(address(_tokenManager.usd1()));
        vm.expectRevert(_errorMessage(Errors.ADDRESS_CODE_SIZE_ZERO));
        vm.prank(_timelock);
        _tokenManager.setUSD1(vm.addr(0x10000));
    }
    function test_setUSD1_UpdatedWhenReplacing() public {
        address oldToken = address(_tokenManager.usd1());
        address[] memory tokens;
        (address[] memory pairTokensX, address[] memory pairTokensY) = _getPairAddresses(oldToken);
        _assertTokensAndPairsRemoved(tokens, pairTokensX, pairTokensY);
        IERC20Token newToken = _deployUnitasERC20Token("Unitas 1", "USD1");
        vm.prank(_timelock);
        _tokenManager.setUSD1(address(newToken));
        assertEq(address(_tokenManager.usd1()), address(newToken), "new usd1");
        ITokenManager.TokenType oldTokenType = _tokenManager.getTokenType(address(oldToken));
        assertEq(uint8(oldTokenType), uint8(ITokenManager.TokenType.Undefined), "old token type");
        ITokenManager.TokenType newTokenType = _tokenManager.getTokenType(address(newToken));
        assertEq(uint8(newTokenType), uint8(ITokenManager.TokenType.Stable), "new token type");
    }
    function test_setUSD1_UpdatedAfterRemoving() public {
        address oldToken = address(_tokenManager.usd1());
        _assertTokenAndPairsRemoved(oldToken);
        IERC20Token newToken = _deployUnitasERC20Token("Unitas 1", "USD1");
        vm.prank(_timelock);
        _tokenManager.setUSD1(address(newToken));
        assertEq(address(_tokenManager.usd1()), address(newToken), "new usd1");
        ITokenManager.TokenType oldTokenType = _tokenManager.getTokenType(address(oldToken));
        assertEq(uint8(oldTokenType), uint8(ITokenManager.TokenType.Undefined), "old token type");
        ITokenManager.TokenType newTokenType = _tokenManager.getTokenType(address(newToken));
        assertEq(uint8(newTokenType), uint8(ITokenManager.TokenType.Stable), "new token type");
    }
    function test_setMinMaxPriceTolerance_FailWhenNotTimelock() public {
        vm.expectRevert(abi.encodeWithSignature("NotTimelock(address)", address(this)));
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 1e18, 1e18);
    }
    function test_setMinMaxPriceTolerance_FailWhenMaxPriceZero() public {
        vm.expectRevert(_errorMessage(Errors.MAX_PRICE_INVALID));
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 0, 0);
    }
    function test_setMinMaxPriceTolerance_FailWhenMinPriceZero() public {
        vm.expectRevert(_errorMessage(Errors.MIN_PRICE_INVALID));
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 0, 1e18);
    }
    function test_setMinMaxPriceTolerance_FailWhenMinPriceGreaterThanMaxPrice() public {
        vm.expectRevert(_errorMessage(Errors.MIN_PRICE_INVALID));
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 1e18 + 1, 1e18);
    }
    function test_setMinMaxPriceTolerance_Updated() public {
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 1, type(uint256).max);
        (uint256 minPrice, uint256 maxPrice) = _tokenManager.getPriceTolerance(address(_usdt));
        assertEq(minPrice, 1, "min price 1");
        assertEq(maxPrice, type(uint256).max, "max price max");
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 1e18, 1e18);
        (minPrice, maxPrice) = _tokenManager.getPriceTolerance(address(_usdt));
        assertEq(minPrice, 1e18, "min price 1e18");
        assertEq(maxPrice, 1e18, "max price 1e18");
        vm.prank(_timelock);
        _tokenManager.setMinMaxPriceTolerance(address(_usdt), 1e18, 1e18 + 1);
        (minPrice, maxPrice) = _tokenManager.getPriceTolerance(address(_usdt));
        assertEq(minPrice, 1e18, "min price 1e18");
        assertEq(maxPrice, 1e18 + 1, "max price 1e18 + 1");
    }
    function test_addTokensAndPairs_FailWhenNotTimelock() public {
        ITokenManager.TokenConfig[] memory tokens;
        ITokenManager.PairConfig[] memory pairs;
        vm.expectRevert(abi.encodeWithSignature("NotTimelock(address)", address(this)));
        _tokenManager.addTokensAndPairs(tokens, pairs);
    }
    function test_addTokensAndPairs_FailWhenTokenExists() public {
        IERC20Token token = _deployUnitasERC20Token("Token", "TOKEN");
        ITokenManager.PairConfig[] memory pairs;
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](2);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(token),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(_usd1),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        vm.expectRevert(abi.encodeWithSignature("TokenAlreadyInPool(address)", address(_usd1)));
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
    }
    function test_addTokensAndPairs_FailWhenPairExists() public {
        bytes memory message = _errorMessage(Errors.PAIR_ALREADY_EXISTS);
        ITokenManager.TokenConfig[] memory tokens;
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usdt),
            quoteToken: address(_usd1),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        vm.expectRevert(message);
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
    }
    function test_addTokensAndPairs_FailWhenTokenNotInPool() public {
        IERC20Token token = _deployUnitasERC20Token("Token", "TOKEN");
        ITokenManager.TokenConfig[] memory tokens;
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(token),
            quoteToken: address(_usd1),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        vm.expectRevert(abi.encodeWithSignature("TokenNotInPool(address)", token));
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(token),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        vm.expectRevert(abi.encodeWithSignature("TokenNotInPool(address)", token));
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
    }
    function test_addTokensAndPairs_FailWhenTokenPriceToleranceInvalid() public {
        IERC20Token token = _deployUnitasERC20Token("Token", "TOKEN");
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](1);
        ITokenManager.PairConfig[] memory pairs;
        tokens[0] = ITokenManager.TokenConfig({
            token: address(token),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: 0
        });
        vm.expectRevert(_errorMessage(Errors.MAX_PRICE_INVALID));
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(token),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 0,
            maxPrice: 1
        });
        vm.expectRevert(_errorMessage(Errors.MIN_PRICE_INVALID));
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(token),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 10e18,
            maxPrice: 5e18
        });
        vm.expectRevert(_errorMessage(Errors.MIN_PRICE_INVALID));
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
    }
    function test_addTokensAndPairs_AddedTokens() public {
        IERC20Token assetToken = _deployUnitasERC20Token("A", "A");
        IERC20Token stableToken = _deployUnitasERC20Token("S1", "S1");
        IERC20Token stableToken2 = _deployUnitasERC20Token("S2", "S2");
        ITokenManager.PairConfig[] memory pairs;
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](3);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(assetToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(stableToken),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[2] = ITokenManager.TokenConfig({
            token: address(stableToken2),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        _assertTokensAndPairsAdded(tokens, pairs);
    }
    function test_addTokensAndPairs_AddedPairs() public {
        IERC20Token stableToken = _deployUnitasERC20Token("S1", "S1");
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](1);
        ITokenManager.PairConfig[] memory pairs;
        tokens[0] = ITokenManager.TokenConfig({
            token: address(stableToken),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        tokens = new ITokenManager.TokenConfig[](0);
        pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(stableToken),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        _assertTokensAndPairsAdded(tokens, pairs);
    }
    function test_addTokensAndPairs_AddedTokensAndPairs() public {
        IERC20Token assetToken = _deployUnitasERC20Token("A", "A");
        IERC20Token stableToken = _deployUnitasERC20Token("S1", "S1");
        IERC20Token stableToken2 = _deployUnitasERC20Token("S2", "S2");
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](3);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(assetToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(stableToken),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[2] = ITokenManager.TokenConfig({
            token: address(stableToken2),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](2);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(assetToken),
            quoteToken: address(_usd1),
            buyFee: 0,
            buyReserveRatioThreshold: 1e18,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        pairs[1] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(stableToken),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 0,
            sellFee: 0.02e6,
            sellReserveRatioThreshold: 0
        });
        _assertTokensAndPairsAdded(tokens, pairs);
    }
    function test_removeTokensAndPairs_FailWhenNotTimelock() public {
        address[] memory tokens;
        address[] memory pairTokensX;
        address[] memory pairTokensY;
        vm.expectRevert(abi.encodeWithSignature("NotTimelock(address)", address(this)));
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function test_removeTokensAndPairs_FailWhenTokenNotInPool() public {
        address[] memory tokens = new address[](1);
        address[] memory pairTokensX;
        address[] memory pairTokensY;
        tokens[0] = vm.addr(0x10001);
        vm.expectRevert(abi.encodeWithSignature("TokenNotInPool(address)", tokens[0]));
        vm.prank(_timelock);
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function test_removeTokensAndPairs_FailWhenPairsNotRemoved() public {
        address[] memory tokens = new address[](1);
        address[] memory pairTokensX;
        address[] memory pairTokensY;
        tokens[0] = address(_usdt);
        vm.expectRevert(_errorMessage(Errors.PAIRS_MUST_REMOVED));
        vm.prank(_timelock);
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function test_removeTokensAndPairs_FailWhenPairTokenLengthMismatched() public {
        address[] memory tokens;
        address[] memory pairTokensX = new address[](1);
        address[] memory pairTokensY;
        pairTokensX[0] = address(_usd1);
        vm.expectRevert(_errorMessage(Errors.ARRAY_LENGTH_MISMATCHED));
        vm.prank(_timelock);
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function test_removeTokensAndPairs_FailWhenPairNotExists() public {
        address[] memory tokens;
        address[] memory pairTokensX = new address[](1);
        address[] memory pairTokensY = new address[](1);
        pairTokensX[0] = address(_usd1);
        pairTokensY[0] = vm.addr(0x10001);
        vm.expectRevert(_errorMessage(Errors.PAIR_NOT_EXISTS));
        vm.prank(_timelock);
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
    }
    function test_removeTokensAndPairs_RemovedPairs() public {
        (address tokenX, address tokenY) = _tokenManager.exposed_sortTokens(address(_usd1), address(_usd91));
        address[] memory tokens;
        address[] memory pairTokensX = new address[](1);
        address[] memory pairTokensY = new address[](1);
        pairTokensX[0] = tokenX;
        pairTokensY[0] = tokenY;
        _assertTokensAndPairsRemoved(tokens, pairTokensX, pairTokensY);
    }
    function test_removeTokensAndPairs_RemovedTokensAndPairs() public {
        (address tokenX, address tokenY) = _tokenManager.exposed_sortTokens(address(_usd1), address(_usd91));
        address[] memory tokens = new address[](1);
        address[] memory pairTokensX = new address[](1);
        address[] memory pairTokensY = new address[](1);
        tokens[0] = address(_usd91);
        pairTokensX[0] = tokenX;
        pairTokensY[0] = tokenY;
        _assertTokensAndPairsRemoved(tokens, pairTokensX, pairTokensY);
    }
    function test_updatePairs_FailWhenTokenNotExists() public {
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: vm.addr(0x10001),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        vm.expectRevert(abi.encodeWithSignature("TokenNotInPool(address)", vm.addr(0x10001)));
        vm.prank(_timelock);
        _tokenManager.updatePairs(pairs);
    }
    function test_updatePairs_FailWhenPairInvalid() public {
        bytes memory message = _errorMessage(Errors.PAIR_INVALID);
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd1),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        vm.expectRevert(message);
        vm.prank(_timelock);
        _tokenManager.updatePairs(pairs);
    }
    function test_updatePairs_FailWhenPairNotExists() public {
        bytes memory message = _errorMessage(Errors.PAIR_NOT_EXISTS);
        IERC20Token assetToken = _deployUnitasERC20Token("A", "A");
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](1);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(assetToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs;
        _assertTokensAndPairsAdded(tokens, pairs);
        pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(assetToken),
            quoteToken: address(_usd1),
            buyFee: 0,
            buyReserveRatioThreshold: 1e18,
            sellFee: 0,
            sellReserveRatioThreshold: 1.3e18
        });
        vm.expectRevert(message);
        vm.prank(_timelock);
        _tokenManager.updatePairs(pairs);
    }
    function test_updatePairs_Updated() public {
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](3);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 1.4e18,
            sellFee: 0.02e6,
            sellReserveRatioThreshold: 1.5e18
        });
        pairs[1] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd91),
            buyFee: 0.03e6,
            buyReserveRatioThreshold: 1.6e18,
            sellFee: 0.04e6,
            sellReserveRatioThreshold: 1.7e18
        });
        pairs[2] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd971),
            buyFee: 0.05e6,
            buyReserveRatioThreshold: 1.8e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        for (uint256 i = 0; i < pairs.length; i++) {
            ITokenManager.PairConfig memory pair = pairs[i];
            bytes32 pairHash = _tokenManager.getPairHash(pair.baseToken, pair.quoteToken);
            vm.expectEmit(true, true, true, true, address(_tokenManager));
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
        vm.prank(_timelock);
        _tokenManager.updatePairs(pairs);
        for (uint256 i = 0; i < pairs.length; i++) {
            _assertPairsEqual(_tokenManager.getPair(pairs[i].baseToken, pairs[i].quoteToken), pairs[i]);
        }
    }
    function test_listPairsByIndexAndCount_FailWhenIndexPlusCountInvalid() public {
        uint256 pairCount = _tokenManager.pairLength();
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenManager.listPairsByIndexAndCount(pairCount, 0);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenManager.listPairsByIndexAndCount(0, pairCount + 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenManager.listPairsByIndexAndCount(pairCount - 1, 2);
    }
    function test_listPairsByIndexAndCount_FailWhenIndexPlusCountInvalidAndPairsEmpty() public {
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](3);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(_usdt),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(_usd91),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[2] = ITokenManager.TokenConfig({
            token: address(_usd971),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs;
        TokenManagerHarness tokenManager = _deployTokenManager(tokens, pairs);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        tokenManager.listPairsByIndexAndCount(0, 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        tokenManager.listPairsByIndexAndCount(1, 0);
    }
    function test_listPairsByIndexAndCount_WhenPairsEmpty() public {
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](3);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(_usdt),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(_usd91),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[2] = ITokenManager.TokenConfig({
            token: address(_usd971),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs;
        TokenManagerHarness tokenManager = _deployTokenManager(tokens, pairs);
        pairs = tokenManager.listPairsByIndexAndCount(0, 0);
        assertEq(pairs.length, 0, "pairs length when index 0 and size 0");
    }
    function test_listPairsByIndexAndCount_Correct() public {
        uint256 pairCount = _tokenManager.pairLength();
        IERC20Token assetToken = _deployUnitasERC20Token("A", "A");
        IERC20Token stableToken = _deployUnitasERC20Token("S1", "S1");
        IERC20Token stableToken2 = _deployUnitasERC20Token("S2", "S2");
        ITokenManager.TokenConfig[] memory tokensToAdd = new ITokenManager.TokenConfig[](3);
        tokensToAdd[0] = ITokenManager.TokenConfig({
            token: address(assetToken),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokensToAdd[1] = ITokenManager.TokenConfig({
            token: address(stableToken),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokensToAdd[2] = ITokenManager.TokenConfig({
            token: address(stableToken2),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairsToAdd = new ITokenManager.PairConfig[](3);
        pairsToAdd[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(assetToken),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 1.4e18,
            sellFee: 0.02e6,
            sellReserveRatioThreshold: 1.5e18
        });
        pairsToAdd[1] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(stableToken),
            buyFee: 0.03e6,
            buyReserveRatioThreshold: 1.6e18,
            sellFee: 0.04e6,
            sellReserveRatioThreshold: 1.7e18
        });
        pairsToAdd[2] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(stableToken2),
            buyFee: 0.05e6,
            buyReserveRatioThreshold: 1.8e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        _assertTokensAndPairsAdded(tokensToAdd, pairsToAdd);
        ITokenManager.PairConfig[] memory pairs = _tokenManager.listPairsByIndexAndCount(0, pairCount + 3);
        assertEq(pairs.length, pairCount + 3, "pair length after adding 3 pairs");
        _assertPairsEqual(pairs[pairCount], pairsToAdd[0]);
        _assertPairsEqual(pairs[pairCount + 1], pairsToAdd[1]);
        _assertPairsEqual(pairs[pairCount + 2], pairsToAdd[2]);
        address[] memory tokensToRemove = new address[](1);
        address[] memory pairTokensXToRemove = new address[](1);
        address[] memory pairTokensYToRemove = new address[](1);
        tokensToRemove[0] = address(assetToken);
        pairTokensXToRemove[0] = address(_usd1);
        pairTokensYToRemove[0] = address(assetToken);
        _assertTokensAndPairsRemoved(tokensToRemove, pairTokensXToRemove, pairTokensYToRemove);
        pairs = _tokenManager.listPairsByIndexAndCount(0, pairCount + 2);
        assertEq(pairs.length, pairCount + 2, "pair length after removing asset token");
        _assertPairsEqual(pairs[pairCount], pairsToAdd[2]);
        _assertPairsEqual(pairs[pairCount + 1], pairsToAdd[1]);
    }
    function test_getTokenType_Correct() public {
        address invalidAddress = vm.addr(0x1000000);
        _assertTokenTypesEqual(
            _tokenManager.getTokenType(invalidAddress),
            ITokenManager.TokenType.Undefined,
            "token type when not in the pool"
        );
        _assertTokenTypesEqual(
            _tokenManager.getTokenType(address(_usdt)), ITokenManager.TokenType.Asset, "token type when usdt"
        );
        _assertTokenTypesEqual(
            _tokenManager.getTokenType(address(_usd1)), ITokenManager.TokenType.Stable, "token type when usd1"
        );
        _assertTokenTypesEqual(
            _tokenManager.getTokenType(address(_usd91)), ITokenManager.TokenType.Stable, "token type when usd91"
        );
    }
    function test_getPair_FailWhenNotExists() public {
        bytes memory message = _errorMessage(Errors.PAIR_NOT_EXISTS);
        vm.expectRevert(message);
        _tokenManager.getPair(address(_usdt), address(_usdt));
        vm.expectRevert(message);
        _tokenManager.getPair(address(_usd91), address(_usd91));
        vm.expectRevert(message);
        _tokenManager.getPair(address(_usdt), address(_usd91));
        vm.expectRevert(message);
        _tokenManager.getPair(address(_usd91), address(_usdt));
    }
    function test_getPair_Correct() public {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(address(_usdt), address(_usd1));
        ITokenManager.PairConfig memory pair2 = _tokenManager.getPair(address(_usd1), address(_usdt));
        _assertPairsEqual(pair, pair2);
    }
    function test_checkPairParameters_FailWhenTokenNotInPool() public {
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(vm.addr(0x10002)),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(abi.encodeWithSignature("TokenNotInPool(address)", vm.addr(0x10002)));
        vm.prank(_timelock);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_FailWhenUSD1Zero() public {
        _assertTokenAndPairsRemoved(address(_usd1));
        bytes memory message = _errorMessage(Errors.USD1_NOT_SET);
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usdt),
            quoteToken: address(_usd91),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_FailWhenPairInvalid() public {
        bytes memory message = _errorMessage(Errors.PAIR_INVALID);
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd1),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
        pair = ITokenManager.PairConfig({
            baseToken: address(_usdt),
            quoteToken: address(_usd91),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_FailWhenBuyFeeInvalid() public {
        bytes memory message = _errorMessage(Errors.FEE_NUMERATOR_INVALID);
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 1e6,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_FailWhenBuyReserveRatioThresholdInvalid() public {
        bytes memory message = _errorMessage(Errors.RESERVE_RATIO_THRESHOLD_INVALID);
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 1,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
        pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 1e18 - 1,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_FailWhenSellFeeInvalid() public {
        bytes memory message = _errorMessage(Errors.FEE_NUMERATOR_INVALID);
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 1e6,
            sellReserveRatioThreshold: 0
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_FailWhenSellReserveRatioThresholdInvalid() public {
        bytes memory message = _errorMessage(Errors.RESERVE_RATIO_THRESHOLD_INVALID);
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
        pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 1e18 - 1
        });
        vm.expectRevert(message);
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_checkPairParameters_Valid() public view {
        ITokenManager.PairConfig memory pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        _tokenManager.exposed_checkPairParameters(pair);
        pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 0,
            sellFee: 0.01e6,
            sellReserveRatioThreshold: 1e18
        });
        pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0.2e6,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        _tokenManager.exposed_checkPairParameters(pair);
        pair = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0.2e6,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0.01e6,
            sellReserveRatioThreshold: 13e18
        });
        _tokenManager.exposed_checkPairParameters(pair);
    }
    function test_isTokenTypeValid_Invalid() public {
        assertFalse(_tokenManager.exposed_isTokenTypeValid(0));
        assertFalse(_tokenManager.exposed_isTokenTypeValid(uint8(ITokenManager.TokenType.Stable) + 1));
    }
    function test_isTokenTypeValid_Valid() public {
        assertTrue(_tokenManager.exposed_isTokenTypeValid(uint8(ITokenManager.TokenType.Asset)));
        assertTrue(_tokenManager.exposed_isTokenTypeValid(uint8(ITokenManager.TokenType.Stable)));
    }
    function test_checkSwapFeeNumerator_Invalid() public {
        bytes memory message = _errorMessage(Errors.FEE_NUMERATOR_INVALID);
        vm.expectRevert(message);
        _tokenManager.exposed_checkSwapFeeNumerator(1e6);
        vm.expectRevert(message);
        _tokenManager.exposed_checkSwapFeeNumerator(1e6 + 1);
    }
    function test_checkSwapFeeNumerator_Valid() public view {
        _tokenManager.exposed_checkSwapFeeNumerator(0);
        _tokenManager.exposed_checkSwapFeeNumerator(1);
        _tokenManager.exposed_checkSwapFeeNumerator(0.01e6);
        _tokenManager.exposed_checkSwapFeeNumerator(1e6 - 1);
    }
    function test_checkReserveRatioThreshold_Invalid() public {
        bytes memory message = _errorMessage(Errors.RESERVE_RATIO_THRESHOLD_INVALID);
        vm.expectRevert(message);
        _tokenManager.exposed_checkReserveRatioThreshold(1);
        vm.expectRevert(message);
        _tokenManager.exposed_checkReserveRatioThreshold(1e18 - 1);
    }
    function test_checkReserveRatioThreshold_Valid() public view {
        _tokenManager.exposed_checkReserveRatioThreshold(0);
        _tokenManager.exposed_checkReserveRatioThreshold(1e18);
        _tokenManager.exposed_checkReserveRatioThreshold(1e18 + 1);
    }
    function _deployUnitasERC20Token(string memory name, string memory symbol) internal returns (IERC20Token) {
        ERC20Token token = new ERC20Token(name, symbol, _governor, _governor, address(this));
        return IERC20Token(address(token));
    }
    function _deployTokenManager() internal returns (TokenManagerHarness) {
        ITokenManager.TokenConfig[] memory tokens = new ITokenManager.TokenConfig[](3);
        tokens[0] = ITokenManager.TokenConfig({
            token: address(_usdt),
            tokenType: ITokenManager.TokenType.Asset,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[1] = ITokenManager.TokenConfig({
            token: address(_usd91),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        tokens[2] = ITokenManager.TokenConfig({
            token: address(_usd971),
            tokenType: ITokenManager.TokenType.Stable,
            minPrice: 1,
            maxPrice: type(uint256).max
        });
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](3);
        pairs[0] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usdt),
            buyFee: 0,
            buyReserveRatioThreshold: 1.3e18,
            sellFee: 0,
            sellReserveRatioThreshold: 0
        });
        pairs[1] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd91),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 0,
            sellFee: 0.01e6,
            sellReserveRatioThreshold: 1e18
        });
        pairs[2] = ITokenManager.PairConfig({
            baseToken: address(_usd1),
            quoteToken: address(_usd971),
            buyFee: 0.01e6,
            buyReserveRatioThreshold: 0,
            sellFee: 0.01e6,
            sellReserveRatioThreshold: 1e18
        });
        return _deployTokenManager(tokens, pairs);
    }
    function _deployTokenManager(ITokenManager.TokenConfig[] memory tokens, ITokenManager.PairConfig[] memory pairs)
        internal
        returns (TokenManagerHarness)
    {
        return new TokenManagerHarness(_governor, _timelock, address(_usd1), tokens, pairs);
    }
    function _assertSwapFeeUpdated(address tokenIn, address tokenOut, uint24 fee) public {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        if (tokenOut == pair.baseToken) {
            pair.buyFee = fee;
        } else {
            pair.sellFee = fee;
        }
        _assertPairUpdated(pair);
    }
    function _assertReserveRatioThresholdUpdated(address tokenIn, address tokenOut, uint232 threshold) public {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        if (tokenOut == pair.baseToken) {
            pair.buyReserveRatioThreshold = threshold;
        } else {
            pair.sellReserveRatioThreshold = threshold;
        }
        _assertPairUpdated(pair);
    }
    function _assertTokensAndPairsAdded(
        ITokenManager.TokenConfig[] memory tokens,
        ITokenManager.PairConfig[] memory pairs
    ) internal {
        uint256 assetTokenCount = _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Asset));
        uint256 stableTokenCount = _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Stable));
        uint256 pairCount = _tokenManager.pairLength();
        for (uint256 i = 0; i < tokens.length; i++) {
            vm.expectEmit(true, true, true, true, address(_tokenManager));
            emit TokenAdded(tokens[i].token, uint8(tokens[i].tokenType));
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            ITokenManager.PairConfig memory pair = pairs[i];
            (address tokenX, address tokenY) = _tokenManager.exposed_sortTokens(pair.baseToken, pair.quoteToken);
            bytes32 pairHash = _tokenManager.getPairHash(pair.baseToken, pair.quoteToken);
            vm.expectEmit(true, true, true, true, address(_tokenManager));
            emit PairAdded(pairHash, tokenX, tokenY);
            vm.expectEmit(true, true, true, true, address(_tokenManager));
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
        vm.prank(_timelock);
        _tokenManager.addTokensAndPairs(tokens, pairs);
        uint256 assetTokenCounter;
        uint256 stableTokenCounter;
        for (uint256 i = 0; i < tokens.length; i++) {
            assertTrue(_tokenManager.isTokenInPool(tokens[i].token), "token in pool");
            _assertTokenTypesEqual(_tokenManager.getTokenType(tokens[i].token), tokens[i].tokenType, "token type");
            if (tokens[i].tokenType == ITokenManager.TokenType.Asset) {
                assertEq(
                    _tokenManager.tokenByIndex(
                        uint8(ITokenManager.TokenType.Asset), assetTokenCount + assetTokenCounter
                    ),
                    tokens[i].token,
                    "asset token by index"
                );
                assetTokenCounter++;
            } else if (tokens[i].tokenType == ITokenManager.TokenType.Stable) {
                assertEq(
                    _tokenManager.tokenByIndex(
                        uint8(ITokenManager.TokenType.Stable), stableTokenCount + stableTokenCounter
                    ),
                    tokens[i].token,
                    "asset token by index"
                );
                stableTokenCounter++;
            }
        }
        for (uint256 i = 0; i < pairs.length; i++) {
            ITokenManager.PairConfig memory pair = pairs[i];
            assertTrue(_tokenManager.isPairInPool(pair.baseToken, pair.quoteToken), "pair in pool");
            _assertPairsEqual(_tokenManager.pairByIndex(pairCount + i), pairs[i]);
            _assertPairsEqual(_tokenManager.getPair(pair.baseToken, pair.quoteToken), pairs[i]);
            _assertPairsEqual(_tokenManager.getPair(pair.quoteToken, pair.baseToken), pairs[i]);
        }
        assertEq(
            _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Asset)),
            assetTokenCount + assetTokenCounter,
            "asset token count"
        );
        assertEq(
            _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Stable)),
            stableTokenCount + stableTokenCounter,
            "stable token count"
        );
        assertEq(_tokenManager.pairLength(), pairCount + pairs.length, "pair count");
    }
    function _assertTokenAndPairsRemoved(address token) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        (address[] memory pairTokensX, address[] memory pairTokensY) = _getPairAddresses(token);
        _assertTokensAndPairsRemoved(tokens, pairTokensX, pairTokensY);
    }
    function _assertTokensAndPairsRemoved(
        address[] memory tokens,
        address[] memory pairTokensX,
        address[] memory pairTokensY
    ) internal {
        uint256 assetTokenCount = _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Asset));
        uint256 stableTokenCount = _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Stable));
        uint256 pairCount = _tokenManager.pairLength();
        assertEq(pairTokensX.length, pairTokensY.length, "pair tokens x length eq pair tokens y length");
        for (uint256 i = 0; i < pairTokensX.length; i++) {
            (address tokenX, address tokenY) = _tokenManager.exposed_sortTokens(pairTokensX[i], pairTokensY[i]);
            bytes32 pairHash = _tokenManager.getPairHash(tokenX, tokenY);
            vm.expectEmit(true, true, true, true, address(_tokenManager));
            emit PairRemoved(pairHash, tokenX, tokenY);
        }
        uint256 assetTokenCounter;
        uint256 stableTokenCounter;
        for (uint256 i = 0; i < tokens.length; i++) {
            ITokenManager.TokenType tokenType = _tokenManager.getTokenType(tokens[i]);
            vm.expectEmit(true, true, true, true, address(_tokenManager));
            emit TokenRemoved(tokens[i], uint8(tokenType));
            if (tokenType == ITokenManager.TokenType.Asset) {
                assetTokenCounter++;
            } else if (tokenType == ITokenManager.TokenType.Stable) {
                stableTokenCounter++;
            }
        }
        vm.prank(_timelock);
        _tokenManager.removeTokensAndPairs(tokens, pairTokensX, pairTokensY);
        for (uint256 i = 0; i < tokens.length; i++) {
            assertFalse(_tokenManager.isTokenInPool(tokens[i]), "token in pool");
            _assertTokenTypesEqual(
                _tokenManager.getTokenType(tokens[i]), ITokenManager.TokenType.Undefined, "token type"
            );
        }
        for (uint256 i = 0; i < pairTokensX.length; i++) {
            assertFalse(_tokenManager.isPairInPool(pairTokensX[i], pairTokensY[i]), "pair in pool");
        }
        assertEq(
            _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Asset)),
            assetTokenCount - assetTokenCounter,
            "asset token count"
        );
        assertEq(
            _tokenManager.tokenLength(uint8(ITokenManager.TokenType.Stable)),
            stableTokenCount - stableTokenCounter,
            "stable token count"
        );
        assertEq(_tokenManager.pairLength(), pairCount - pairTokensX.length, "pair count");
    }
    function _assertPairUpdated(ITokenManager.PairConfig memory pair) internal {
        bytes32 pairHash = _tokenManager.getPairHash(pair.baseToken, pair.quoteToken);
        ITokenManager.PairConfig[] memory pairs = new ITokenManager.PairConfig[](1);
        pairs[0] = pair;
        vm.expectEmit(true, true, true, true, address(_tokenManager));
        emit PairUpdated(
            pairHash,
            pair.baseToken,
            pair.quoteToken,
            pair.buyFee,
            pair.buyReserveRatioThreshold,
            pair.sellFee,
            pair.sellReserveRatioThreshold
        );
        vm.startPrank(_timelock);
        _tokenManager.updatePairs(pairs);
        vm.stopPrank();
        _assertPairsEqual(_tokenManager.getPair(pair.baseToken, pair.quoteToken), pair);
        _assertPairsEqual(_tokenManager.getPair(pair.quoteToken, pair.baseToken), pair);
    }
    function _assertTokenTypesEqual(
        ITokenManager.TokenType value,
        ITokenManager.TokenType expected,
        string memory message
    ) internal {
        assertEq(uint8(value), uint8(expected), message);
    }
    function _assertPairsEqual(ITokenManager.PairConfig memory value, ITokenManager.PairConfig memory expected)
        internal
    {
        assertEq(value.baseToken, expected.baseToken, "base token");
        assertEq(value.quoteToken, expected.quoteToken, "quote token");
        assertEq(value.buyFee, expected.buyFee, "buy fee");
        assertEq(value.buyReserveRatioThreshold, expected.buyReserveRatioThreshold, "buy reserve ratio threshold");
        assertEq(value.sellFee, expected.sellFee, "sell fee");
        assertEq(value.sellReserveRatioThreshold, expected.sellReserveRatioThreshold, "sell reserve ratio threshold");
    }
    function _assertIncluded(address addr, address[] memory addresses, uint256 times) internal {
        uint256 length = addresses.length;
        uint256 count;
        for (uint256 i; i < length; i++) {
            if (addr == addresses[i]) {
                count++;
            }
        }
        if (count != times) {
            emit log_named_address("address", addr);
        }
        assertEq(count, times, "count of the address included in array");
    }
    function _getFee(address tokenIn, address tokenOut) internal view returns (uint24 fee) {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        fee = tokenOut == pair.baseToken ? pair.buyFee : pair.sellFee;
    }
    function _getReserveRatioThreshold(address tokenIn, address tokenOut)
        internal
        view
        returns (uint232 reserveRatioThreshold)
    {
        ITokenManager.PairConfig memory pair = _tokenManager.getPair(tokenIn, tokenOut);
        reserveRatioThreshold =
            tokenOut == pair.baseToken ? pair.buyReserveRatioThreshold : pair.sellReserveRatioThreshold;
    }
    function _getPairAddresses(address token) internal view returns (address[] memory, address[] memory) {
        uint256 pairTokenCount = _tokenManager.pairTokenLength(address(token));
        address[] memory pairTokensX = new address[](pairTokenCount);
        address[] memory pairTokensY = _tokenManager.listPairTokensByIndexAndCount(token, 0, pairTokenCount);
        for (uint256 i = 0; i < pairTokenCount; i++) {
            pairTokensX[i] = token;
        }
        return (pairTokensX, pairTokensY);
    }
}
contract TokenManagerHarness is TokenManager {
    constructor(
        address governor_,
        address timelock_,
        address usd1_,
        TokenConfig[] memory tokens_,
        PairConfig[] memory pairs_
    ) TokenManager(governor_, timelock_, usd1_, tokens_, pairs_) {}
    function exposed_checkPairParameters(ITokenManager.PairConfig memory pair) external view {
        _checkPairParameters(pair);
    }
    function exposed_checkSwapFeeNumerator(uint24 feeNumerator) external pure {
        _checkSwapFeeNumerator(feeNumerator);
    }
    function exposed_checkReserveRatioThreshold(uint232 reserveRatioThreshold) external pure {
        _checkReserveRatioThreshold(reserveRatioThreshold);
    }
    function exposed_isTokenTypeValid(uint8 tokenType) external pure returns (bool) {
        return _isTokenTypeValid(tokenType);
    }
    function exposed_getPairHash(address tokenX, address tokenY) external pure returns (bytes32) {
        return _getPairHash(tokenX, tokenY);
    }
    function exposed_sortTokens(address tokenX, address tokenY) external pure returns (address, address) {
        return _sortTokens(tokenX, tokenY);
    }
}