pragma solidity ^0.8.19;
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "forge-std/Test.sol";
import "../src/interfaces/IERC20Token.sol";
import "../src/utils/Errors.sol";
import "../src/ERC20Token.sol";
import "../src/SwapFunctions.sol";
import "./mocks/MockERC20Token.sol";
import "./utils/Functions.sol";
contract SwapFunctionsTest is Test {
    using MathUpgradeable for uint256;
    IERC20Token internal _usd1;
    IERC20Token internal _usd91;
    IERC20Token internal _usd971;
    MockERC20Token internal _usdt;
    SwapFunctionsHarness internal _swapFunctions;
    function setUp() public virtual {
        _usd1 = _deployUnitasERC20Token("Unitas 1", "USD1");
        _usd91 = _deployUnitasERC20Token("Unitas 91", "USD91");
        _usd971 = _deployUnitasERC20Token("Unitas 971", "USD971");
        _usdt = new MockERC20Token("Tether USD", "USDT", 6);
        _swapFunctions = new SwapFunctionsHarness();
        vm.label(address(_usd1), "USD1");
        vm.label(address(_usd91), "USD91");
        vm.label(address(_usd971), "USD971");
        vm.label(address(_usdt), "USDT");
    }
    function test_validateFeeFraction_FailWhenInvalid() public {
        bytes memory message = _errorMessage(Errors.FEE_FRACTION_INVALID);
        vm.expectRevert(message);
        _swapFunctions.exposed_validateFeeFraction(1, 0);
        vm.expectRevert(message);
        _swapFunctions.exposed_validateFeeFraction(2, 1);
        vm.expectRevert(message);
        _swapFunctions.exposed_validateFeeFraction(1e6, 1e6);
    }
    function test_validateFeeFraction_Valid() public view {
        _swapFunctions.exposed_validateFeeFraction(0, 0);
        _swapFunctions.exposed_validateFeeFraction(0, 1e6);
        _swapFunctions.exposed_validateFeeFraction(1e6 - 1, 1e6);
    }
    function test_getFeeByAmountWithFee_Correct() public {
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithFee(1e18, 0, 0),
            0,
            "0"
        );
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithFee(1e18, 0.01e6, 1e6),
            0.01e18,
            "1%"
        );
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithFee(100000e18, 0.9999e6, 1e6),
            99990e18,
            "99.99%"
        );
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithFee(1.111111111111111111e18, 0.333333e6, 1e6),
            0.37037e18,
            "33.3333% ceil"
        );
    }
    function test_getFeeByAmountWithoutFee_Correct() public {
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithoutFee(1e18, 0, 0),
            0,
            "0"
        );
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithoutFee(1e18, 0.01e6, 1e6),
            0.010101010101010102e18,
            "1% ceil"
        );
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithoutFee(10e18, 0.9999e6, 1e6),
            99990e18,
            "99.99%"
        );
        assertEq(
            _swapFunctions.exposed_getFeeByAmountWithoutFee(1.111111111111111111e18, 0.333333e6, 1e6),
            0.555554722222638889e18,
            "33.3333333333333333% ceil"
        );
    }
    function test_convert_FailWhenQuoteTokenInvalid() public {
        bytes memory message = _errorMessage(Errors.PARAMETER_INVALID);
        vm.expectRevert(message);
        _swapFunctions.exposed_convert(address(_usdt), address(_usd1), 1e18, MathUpgradeable.Rounding.Down, 1e18, 1e18, address(0x0));
        vm.expectRevert(message);
        _swapFunctions.exposed_convert(address(_usdt), address(_usd1), 1e18, MathUpgradeable.Rounding.Down, 1e18, 1e18, address(_usd91));
    }
    function test_convert_WhenTokensSame() public {
        uint256 fromAmount = 1.23456789012345618e18;
        uint256 toAmount = _swapFunctions.exposed_convert(address(_usd1), address(_usd1), fromAmount, MathUpgradeable.Rounding.Up, 1e18, 1e18, address(0x0));
        assertEq(toAmount, fromAmount, "to amount when round up");
        toAmount = _swapFunctions.exposed_convert(address(_usd1), address(_usd1), fromAmount, MathUpgradeable.Rounding.Down, 1e18, 1e18, address(_usd91));
        assertEq(toAmount, fromAmount, "to amount when round down");
    }
    function test_convert_WhenFromAmountZero() public {
        uint256 fromAmount = 0;
        uint256 price = 79.123456789e18;
        uint256 toAmount = _swapFunctions.exposed_convert(address(_usd1), address(_usd91), fromAmount, MathUpgradeable.Rounding.Up, price, 1e18, address(_usd91));
        assertEq(toAmount, fromAmount, "to amount when usd1 to usd91 with round up");
        toAmount = _swapFunctions.exposed_convert(address(_usd1), address(_usd91), fromAmount, MathUpgradeable.Rounding.Down, price, 1e18, address(_usd91));
        assertEq(toAmount, fromAmount, "to amount when usd1 to usd91 with round down");
        toAmount = _swapFunctions.exposed_convert(address(_usd91), address(_usd1), fromAmount, MathUpgradeable.Rounding.Up, price, 1e18, address(_usd91));
        assertEq(toAmount, fromAmount, "to amount when usd91 to usd1 with round up");
        toAmount = _swapFunctions.exposed_convert(address(_usd91), address(_usd1), fromAmount, MathUpgradeable.Rounding.Down, price, 1e18, address(_usd91));
        assertEq(toAmount, fromAmount, "to amount when usd91 to usd1 with round down");
    }
    function test_convertByToPrice_FailWhenPriceZero() public {
        vm.expectRevert();
        _swapFunctions.exposed_convertByToPrice(address(_usdt), address(_usd1), 1e18, MathUpgradeable.Rounding.Down, 0, 1e18);
    }
    function testFuzz_convert_WhenAssetTokenAndUSD1(uint128 fromAmount, uint112 price) public {
        fromAmount = uint128(bound(fromAmount, 0.000001e6, type(uint128).max));
        price = uint112(bound(price, 0.000001e18, type(uint112).max));
        _assertConvertCorrect(address(_usdt), address(_usd1), fromAmount, MathUpgradeable.Rounding.Up, price, 18);
        _assertConvertCorrect(address(_usdt), address(_usd1), fromAmount, MathUpgradeable.Rounding.Down, price, 18);
        _assertConvertCorrect(address(_usd1), address(_usdt), fromAmount, MathUpgradeable.Rounding.Up, price, 18);
        _assertConvertCorrect(address(_usd1), address(_usdt), fromAmount, MathUpgradeable.Rounding.Down, price, 18);
    }
    function testFuzz_convert_WhenUSD1AndStableToken(uint128 fromAmount, uint112 price) public {
        fromAmount = uint128(bound(fromAmount, 0.00000001e18, type(uint128).max));
        price = uint112(bound(price, 0.00000001e18, type(uint112).max));
        _assertConvertCorrect(address(_usd1), address(_usd91), fromAmount, MathUpgradeable.Rounding.Up, price, 18);
        _assertConvertCorrect(address(_usd1), address(_usd91), fromAmount, MathUpgradeable.Rounding.Down, price, 18);
        _assertConvertCorrect(address(_usd91), address(_usd1), fromAmount, MathUpgradeable.Rounding.Up, price, 18);
        _assertConvertCorrect(address(_usd91), address(_usd1), fromAmount, MathUpgradeable.Rounding.Down, price, 18);
    }
    function testFuzz_convertByFromPrice_Correct(uint128 fromAmount, uint96 fromPrice) public {
        fromAmount = uint128(bound(fromAmount, 0.00000001e18, type(uint128).max));
        fromPrice = uint96(bound(fromPrice, 0.00000001e18, type(uint96).max));
        uint8 priceDecimals = 18;
        _assertConvertByFromPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 24, 4, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 4, 24, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 24, 4, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 4, 24, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
    }
    function testFuzz_convertByFromPrice_CorrectWhenScaledPriceDecimals(uint128 fromAmount, uint96 fromPrice, uint8 priceDecimals) public {
        fromAmount = uint128(bound(fromAmount, 0.000001e18, type(uint128).max));
        fromPrice = uint96(bound(fromPrice, 0.000001e18, type(uint96).max));
        priceDecimals = uint8(bound(priceDecimals, 6, 12));
        fromPrice = uint96(fromPrice / (10 ** (18 - priceDecimals)));
        _assertConvertByFromPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Up, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
        _assertConvertByFromPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Down, fromPrice, priceDecimals);
    }
    function testFuzz_convertByToPrice_Correct(uint128 fromAmount, uint96 toPrice) public {
        fromAmount = uint128(bound(fromAmount, 0.00000001e18, type(uint128).max));
        toPrice = uint96(bound(toPrice, 0.00000001e18, type(uint96).max));
        uint8 priceDecimals = 18;
        _assertConvertByToPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 24, 4, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 4, 24, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 24, 4, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 4, 24, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
    }
    function testFuzz_convertByToPrice_CorrectWhenScaledPriceDecimals(uint128 fromAmount, uint96 toPrice, uint8 priceDecimals) public {
        fromAmount = uint128(bound(fromAmount, 0.000001e18, type(uint128).max));
        toPrice = uint96(bound(toPrice, 0.000001e18, type(uint96).max));
        priceDecimals = uint8(bound(priceDecimals, 6, 12));
        toPrice = uint96(toPrice / (10 ** (18 - priceDecimals)));
        _assertConvertByToPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Up, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 18, 18, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 18, 6, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
        _assertConvertByToPriceCorrect(fromAmount, 6, 18, MathUpgradeable.Rounding.Down, toPrice, priceDecimals);
    }
    function _assertConvertCorrect(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint8 priceDecimals
    ) internal {
        address quoteToken;
        uint256 expectedToAmount;
        string memory message;
        bool isRoundUp = rounding == MathUpgradeable.Rounding.Up;
        if (fromToken == address(_usd1)) {
            quoteToken = toToken;
            expectedToAmount = isRoundUp
                ? _convertByFromPriceWhenRoundUp(fromToken, toToken, fromAmount, price, priceDecimals)
                : _convertByFromPriceWhenRoundDown(fromToken, toToken, fromAmount, price, priceDecimals);
            message = isRoundUp ? "to amount by from price when round up" : "to amount by from price when round down";
        } else {
            quoteToken = fromToken;
            expectedToAmount = isRoundUp
                ? _convertByToPriceWhenRoundUp(fromToken, toToken, fromAmount, price, priceDecimals)
                : _convertByToPriceWhenRoundDown(fromToken, toToken, fromAmount, price, priceDecimals);
            message = isRoundUp ? "to amount by to price when round up" : "to amount by to price when round down";
        }
        uint256 toAmount = _swapFunctions.exposed_convert(
            fromToken,
            toToken,
            fromAmount,
            rounding,
            price,
            10 ** priceDecimals,
            quoteToken
        );
        assertEq(toAmount, expectedToAmount, message);
    }
    function _assertConvertByFromPriceCorrect(
        uint256 fromAmount,
        uint8 fromDecimals,
        uint8 toDecimals,
        MathUpgradeable.Rounding rounding,
        uint256 fromPrice,
        uint8 priceDecimals
    ) internal {
        MockERC20Token fromToken = new MockERC20Token("From Token", "FROM", fromDecimals);
        MockERC20Token toToken = new MockERC20Token("To Token", "TO", toDecimals);
        _assertConvertByFromPriceCorrect(address(fromToken), address(toToken), fromAmount, rounding, fromPrice, priceDecimals);
    }
    function _assertConvertByFromPriceCorrect(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 fromPrice,
        uint8 priceDecimals
    ) internal {
        bool isRoundUp = rounding == MathUpgradeable.Rounding.Up;
        uint256 expectedToAmount = isRoundUp
            ? _convertByFromPriceWhenRoundUp(fromToken, toToken, fromAmount, fromPrice, priceDecimals)
            : _convertByFromPriceWhenRoundDown(fromToken, toToken, fromAmount, fromPrice, priceDecimals);
        string memory message =
            isRoundUp ? "to amount by from price when round up" : "to amount by from price when round down";
        uint256 toAmount = _swapFunctions.exposed_convertByFromPrice(fromToken, toToken, fromAmount, rounding, fromPrice, 10 ** priceDecimals);
        assertEq(toAmount, expectedToAmount, message);
    }
    function _assertConvertByToPriceCorrect(
        uint256 fromAmount,
        uint8 fromDecimals,
        uint8 toDecimals,
        MathUpgradeable.Rounding rounding,
        uint256 toPrice,
        uint8 priceDecimals
    ) internal {
        MockERC20Token fromToken = new MockERC20Token("From Token", "FROM", fromDecimals);
        MockERC20Token toToken = new MockERC20Token("To Token", "TO", toDecimals);
        _assertConvertByToPriceCorrect(address(fromToken), address(toToken), fromAmount, rounding, toPrice, priceDecimals);
    }
    function _assertConvertByToPriceCorrect(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 toPrice,
        uint8 priceDecimals
    ) internal {
        bool isRoundUp = rounding == MathUpgradeable.Rounding.Up;
        uint256 expectedToAmount = isRoundUp
            ? _convertByToPriceWhenRoundUp(fromToken, toToken, fromAmount, toPrice, priceDecimals)
            : _convertByToPriceWhenRoundDown(fromToken, toToken, fromAmount, toPrice, priceDecimals);
        string memory message =
            isRoundUp ? "to amount by to price when round up" : "to amount by to price when round down";
        uint256 toAmount = _swapFunctions.exposed_convertByToPrice(fromToken, toToken, fromAmount, rounding, toPrice, 10 ** priceDecimals);
        assertEq(toAmount, expectedToAmount, message);
    }
    function _deployUnitasERC20Token(string memory name, string memory symbol) internal returns (IERC20Token) {
        ERC20Token token = new ERC20Token(name, symbol, address(this), address(this), address(this));
        return IERC20Token(address(token));
    }
    function _convertByFromPriceWhenRoundUp(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 fromPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        if (toDecimals > fromDecimals && priceDecimals < (toDecimals - fromDecimals)) {
            uint8 decimalDiff = toDecimals - fromDecimals - priceDecimals;
            fromPrice = fromPrice * 10 ** decimalDiff;
            priceDecimals += decimalDiff;
        }
        return (fromAmount * fromPrice).ceilDiv(10 ** (fromDecimals + priceDecimals - toDecimals));
    }
    function _convertByFromPriceWhenRoundDown(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 fromPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        if (toDecimals > fromDecimals && priceDecimals < (toDecimals - fromDecimals)) {
            uint8 decimalDiff = toDecimals - fromDecimals - priceDecimals;
            fromPrice = fromPrice * 10 ** decimalDiff;
            priceDecimals += decimalDiff;
        }
        return fromAmount * fromPrice / (10 ** (fromDecimals + priceDecimals - toDecimals));
    }
    function _convertByToPriceWhenRoundUp(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        if (fromDecimals > toDecimals && priceDecimals < (fromDecimals - toDecimals)) {
            uint8 decimalDiff = fromDecimals - toDecimals - priceDecimals;
            toPrice = toPrice * 10 ** decimalDiff;
            priceDecimals += decimalDiff;
        }
        return (fromAmount * (10 ** (toDecimals + priceDecimals - fromDecimals))).ceilDiv(toPrice);
    }
    function _convertByToPriceWhenRoundDown(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toPrice,
        uint8 priceDecimals
    ) internal view returns (uint256) {
        uint8 fromDecimals = IERC20Metadata(fromToken).decimals();
        uint8 toDecimals = IERC20Metadata(toToken).decimals();
        if (fromDecimals > toDecimals && priceDecimals < (fromDecimals - toDecimals)) {
            uint8 decimalDiff = fromDecimals - toDecimals - priceDecimals;
            toPrice = toPrice * 10 ** decimalDiff;
            priceDecimals += decimalDiff;
        }
        return fromAmount * (10 ** (toDecimals + priceDecimals - fromDecimals)) / toPrice;
    }
}
contract SwapFunctionsHarness is SwapFunctions {
    constructor() {}
    function exposed_validateFeeFraction(uint256 numerator, uint256 denominator)
        external
        view
    {
       _validateFeeFraction(numerator, denominator);
    }
    function exposed_getFeeByAmountWithFee(uint256 amount, uint256 feeNumerator, uint256 feeDenominator)
        external
        view
        returns (uint256)
    {
        return _getFeeByAmountWithFee(amount, feeNumerator, feeDenominator);
    }
    function exposed_getFeeByAmountWithoutFee(uint256 amount, uint256 feeNumerator, uint256 feeDenominator)
        external
        view
        returns (uint256)
    {
        return _getFeeByAmountWithoutFee(amount, feeNumerator, feeDenominator);
    }
    function exposed_convert(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint256 priceBase,
        address quoteToken
    ) external view returns (uint256) {
        return _convert(fromToken, toToken, fromAmount, rounding, price, priceBase, quoteToken);
    }
    function exposed_convertByFromPrice(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint256 priceBase
    ) external view returns (uint256) {
        return _convertByFromPrice(fromToken, toToken, fromAmount, rounding, price, priceBase);
    }
    function exposed_convertByToPrice(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        MathUpgradeable.Rounding rounding,
        uint256 price,
        uint256 priceBase
    ) external view returns (uint256) {
        return _convertByToPrice(fromToken, toToken, fromAmount, rounding, price, priceBase);
    }
}