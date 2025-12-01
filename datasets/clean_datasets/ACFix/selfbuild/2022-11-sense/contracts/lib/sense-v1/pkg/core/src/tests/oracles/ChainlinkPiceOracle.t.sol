pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { ChainlinkPriceOracle, FeedRegistryLike } from "../../adapters/implementations/oracles/ChainlinkPriceOracle.sol";
import { MockToken } from "../test-helpers/mocks/MockToken.sol";
import { MockChainlinkPriceOracle, MockFeedRegistry } from "../test-helpers/mocks/MockChainlinkPriceOracle.sol";
import { AddressBook } from "../test-helpers/AddressBook.sol";
import { FixedMath } from "../../external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
contract ChainPriceOracleTestHelper is Test {
    using FixedMath for uint256;
    ChainlinkPriceOracle internal oracle;
    MockToken internal underlying;
    function setUp() public {
        oracle = new ChainlinkPriceOracle(0);
        underlying = new MockToken("Underlying Token", "UT", 18);
    }
}
contract ChainlinkPriceOracleTest is ChainPriceOracleTestHelper {
    using FixedMath for uint256;
    function testMainnetDeployOracle() public {
        ChainlinkPriceOracle otherOracle = new ChainlinkPriceOracle(12345);
        assertTrue(address(otherOracle) != address(0));
        assertEq(address(otherOracle.feedRegistry()), AddressBook.CHAINLINK_REGISTRY);
        assertEq(otherOracle.maxSecondsBeforePriceIsStale(), 12345);
    }
    function testPriceWithETH() public {
        MockFeedRegistry feedRegistry = new MockFeedRegistry();
        MockChainlinkPriceOracle oracle = new MockChainlinkPriceOracle(feedRegistry);
        assertEq(oracle.price(AddressBook.WETH), 1e18);
        vm.mockCall(address(feedRegistry), abi.encodeWithSelector(feedRegistry.decimals.selector), abi.encode(18));
        uint256 price = 123e18;
        bytes memory data = abi.encode(1, int256(price), block.timestamp, block.timestamp, 1); 
        vm.mockCall(
            address(feedRegistry),
            abi.encodeWithSelector(feedRegistry.latestRoundData.selector, address(underlying), oracle.ETH()),
            data
        );
        assertEq(oracle.price(address(underlying)), price);
    }
    function testPriceWithUSD() public {
        MockFeedRegistry feedRegistry = new MockFeedRegistry();
        MockChainlinkPriceOracle oracle = new MockChainlinkPriceOracle(feedRegistry);
        vm.mockCall(address(feedRegistry), abi.encodeWithSelector(feedRegistry.decimals.selector), abi.encode(18));
        feedRegistry.setRevert(address(underlying), oracle.ETH(), "Feed not found");
        uint256 underUsdPrice = 456e18;
        bytes memory data = abi.encode(1, int256(underUsdPrice), block.timestamp, block.timestamp, 1); 
        vm.mockCall(
            address(feedRegistry),
            abi.encodeWithSelector(feedRegistry.latestRoundData.selector, address(underlying), oracle.USD()),
            data
        );
        uint256 ethUsdPrice = 789e18;
        data = abi.encode(1, int256(ethUsdPrice), block.timestamp, block.timestamp, 1); 
        vm.mockCall(
            address(feedRegistry),
            abi.encodeWithSelector(feedRegistry.latestRoundData.selector, oracle.ETH(), oracle.USD()),
            data
        );
        assertEq(oracle.price(address(underlying)), underUsdPrice.fmul(1e26).fdiv(1e18).fdiv(ethUsdPrice));
    }
    function testPriceWithBTC() public {
        MockFeedRegistry feedRegistry = new MockFeedRegistry();
        MockChainlinkPriceOracle oracle = new MockChainlinkPriceOracle(feedRegistry);
        vm.mockCall(address(feedRegistry), abi.encodeWithSelector(feedRegistry.decimals.selector), abi.encode(18));
        feedRegistry.setRevert(address(underlying), oracle.ETH(), "Feed not found");
        feedRegistry.setRevert(address(underlying), oracle.USD(), "Feed not found");
        uint256 underBtcPrice = 456e18;
        bytes memory data = abi.encode(1, int256(underBtcPrice), block.timestamp, block.timestamp, 1); 
        vm.mockCall(
            address(feedRegistry),
            abi.encodeWithSelector(feedRegistry.latestRoundData.selector, address(underlying), oracle.BTC()),
            data
        );
        uint256 btcEthPrice = 789e18;
        data = abi.encode(1, int256(btcEthPrice), block.timestamp, block.timestamp, 1); 
        vm.mockCall(
            address(feedRegistry),
            abi.encodeWithSelector(feedRegistry.latestRoundData.selector, oracle.BTC(), oracle.ETH()),
            data
        );
        assertEq(oracle.price(address(underlying)), underBtcPrice.fmul(btcEthPrice).fdiv(1e18));
    }
    function testPriceRevertsWhenNoPriceExists() public {
        MockFeedRegistry feedRegistry = new MockFeedRegistry();
        MockChainlinkPriceOracle oracle = new MockChainlinkPriceOracle(feedRegistry);
        vm.mockCall(address(feedRegistry), abi.encodeWithSelector(feedRegistry.decimals.selector), abi.encode(18));
        feedRegistry.setRevert(address(underlying), oracle.ETH(), "Feed not found");
        feedRegistry.setRevert(address(underlying), oracle.USD(), "Feed not found");
        feedRegistry.setRevert(address(underlying), oracle.BTC(), "Feed not found");
        vm.expectRevert(abi.encodeWithSelector(Errors.PriceOracleNotFound.selector));
        oracle.price(address(underlying));
    }
    function testPriceAttemptFailed() public {
        MockFeedRegistry feedRegistry = new MockFeedRegistry();
        MockChainlinkPriceOracle oracle = new MockChainlinkPriceOracle(feedRegistry);
        vm.mockCall(address(feedRegistry), abi.encodeWithSelector(feedRegistry.decimals.selector), abi.encode(18));
        feedRegistry.setRevert(address(underlying), oracle.ETH(), "Test");
        vm.expectRevert(abi.encodeWithSelector(Errors.AttemptFailed.selector));
        oracle.price(address(underlying));
    }
    function testShouldRevertIfPriceIsStale() public {
        vm.warp(12345678);
        oracle.setMaxSecondsBeforePriceIsStale(4 hours);
        FeedRegistryLike feedRegistry = FeedRegistryLike(oracle.feedRegistry());
        vm.mockCall(address(feedRegistry), abi.encodeWithSelector(feedRegistry.decimals.selector), abi.encode(18));
        uint256 price = 123e18;
        bytes memory data = abi.encode(
            1,
            int256(price),
            block.timestamp - 4 hours - 1 seconds,
            block.timestamp - 4 hours - 1 seconds,
            1
        ); 
        vm.mockCall(
            address(feedRegistry),
            abi.encodeWithSelector(feedRegistry.latestRoundData.selector, address(underlying), oracle.ETH()),
            data
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidPrice.selector));
        oracle.price(address(underlying));
    }
    function testCantSetMaxSecondsBeforePriceIsStaleIfNotTrusted() public {
        vm.prank(address(123));
        vm.expectRevert("UNTRUSTED");
        oracle.setMaxSecondsBeforePriceIsStale(12345);
    }
    function testSetMaxSecondsBeforePriceIsStaleIfNotTrusted() public {
        assertEq(oracle.maxSecondsBeforePriceIsStale(), 0);
        oracle.setMaxSecondsBeforePriceIsStale(12345);
        assertEq(oracle.maxSecondsBeforePriceIsStale(), 12345);
    }
}