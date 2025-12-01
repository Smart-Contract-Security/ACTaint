pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/ERC20Token.sol";
import "../src/XOracle.sol";
import "../src/interfaces/IOracle.sol";
contract XOracleTest is Test {
    XOracle public oracle;
    ERC20Token usd91;
    ERC20Token usd971;
    function setUp() public {
        usd91 =  new ERC20Token("USD91", "USD91", address(this), address(this), address(this));
        usd971 = new ERC20Token("USD971", "USD971", address(this), address(this), address(this));
        oracle = new XOracle();
    }
    function testPutPrice() public {
        oracle.putPrice(address(usd971), 1681964400, 1e18);
    }
    function testUpdatePrices() public {
        IOracle.NewPrice[] memory prices = new IOracle.NewPrice[](2);
        prices[0] = IOracle.NewPrice(address(usd91), 1681964400, 1e18);
        prices[1] = IOracle.NewPrice(address(usd971), 1681964401, 2e18);
        oracle.updatePrices(prices);
        (uint64 timestamp, uint64 prev_timestamp, uint256 price, uint256 prev_price) = oracle.getPrice(address(usd91));
        assertEq(timestamp, 1681964400);
        assertEq(price, 1e18);
        (timestamp, prev_timestamp, price, prev_price) = oracle.getPrice(address(usd971));
        assertEq(timestamp, 1681964401);
        assertEq(price, 2e18);
    }
    function testGetPrice() public {
        (uint64 timestamp, uint64 prev_timestamp, uint256 price, uint256 prev_price) = oracle.getPrice(address(usd971));
        assertEq(timestamp, 0);
        assertEq(price, 0);
        assertEq(prev_timestamp, 0);
        assertEq(prev_price, 0);
        oracle.putPrice(address(usd971), 1681964400, 1e18);
        (timestamp, prev_timestamp, price, prev_price) = oracle.getPrice(address(usd971));
        assertEq(timestamp, 1681964400);
        assertEq(price, 1e18);
        assertEq(prev_timestamp, 0);
        assertEq(prev_price, 0);
    }
    function testDecimals_ShouldAlwaysReturns18() public {
        assertEq(oracle.decimals(), 18);
    }
    function testPutPrice_ShouldFail_WhenCallerIsNonFeeder() public {
        vm.prank(address(0));
        vm.expectRevert();
        oracle.putPrice(address(usd971), 1681964400, 1e18);
    }
    function testPutPrice_ShouldFail_WhenTimestampIsOutdated() public {
        oracle.putPrice(address(usd971), 1681964400, 1e18);
        vm.expectRevert("Outdated timestamp");
        oracle.putPrice(address(usd971), 1681964400, 1e18);
        vm.expectRevert("Outdated timestamp");
        oracle.putPrice(address(usd971), 1681964400-1, 1e18);
    }
    function testUpdatePrices_ShouldFail_WhenCallerIsNonFeeder() public {
        IOracle.NewPrice[] memory prices = new IOracle.NewPrice[](2);
        prices[0] = IOracle.NewPrice(address(usd91), 1681964400, 1e18);
        prices[1] = IOracle.NewPrice(address(usd971), 1681964401, 2e18);
        vm.prank(address(0));
        vm.expectRevert();
        oracle.updatePrices(prices);
    }
    function testUpdatePrices_ShouldFail_WhenTimestampIsOutdated() public {
        IOracle.NewPrice[] memory prices = new IOracle.NewPrice[](2);
        prices[0] = IOracle.NewPrice(address(usd91), 1681964400, 1e18);
        prices[1] = IOracle.NewPrice(address(usd971), 1681964401, 2e18);
        oracle.updatePrices(prices);
        prices[0] = IOracle.NewPrice(address(usd91), 1681964400, 1e18);
        prices[1] = IOracle.NewPrice(address(usd971), 1681964401, 2e18);
        vm.expectRevert("Outdated timestamp");
        oracle.updatePrices(prices);
        prices[0] = IOracle.NewPrice(address(usd91), 1681964400-1, 1e18);
        prices[1] = IOracle.NewPrice(address(usd971), 1681964401-1, 2e18);
        vm.expectRevert("Outdated timestamp");
        oracle.updatePrices(prices);
    }
    function invariant_TimestampShouldAlwaysGreaterThenPrevTimestamp() public {
        (uint64 usd91_current_timestamp, uint64 usd91_prev_timestamp, , ) = oracle.getPrice(address(usd91));
        (uint64 usd971_current_timestamp, uint64 usd971_prev_timestamp, , ) = oracle.getPrice(address(usd971));
        if (usd91_current_timestamp != 0)
            assertEq(usd91_current_timestamp > usd91_prev_timestamp, true);
        if (usd971_current_timestamp != 0)
            assertEq(usd971_current_timestamp > usd971_prev_timestamp, true);
    }
}
contract XOracleFuzz is Test {
    XOracle public oracle;
    ERC20Token usd91;
    ERC20Token usd971;
    function setUp() public {
        oracle = new XOracle();
    }
    function testPutPrice(address _token, uint64 _timestamp, uint256 _price) public {
        vm.assume(_timestamp > 0);
        oracle.putPrice(_token, _timestamp, _price);
    }
}