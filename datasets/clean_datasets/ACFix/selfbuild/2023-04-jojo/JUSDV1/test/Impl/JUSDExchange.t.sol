pragma solidity ^0.8.9;
import "forge-std/Test.sol";
import "../mocks/MockERC20.sol";
import "../../src/token/JUSD.sol";
import "../../src/Impl/JUSDExchange.sol";
import "../mocks/MockJOJODealer.sol";
interface Cheats {
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}
contract JUSDExchangeTest is Test {
    Cheats internal constant cheats =
        Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    JUSD public jusd;
    MockERC20 public usdc;
    address internal alice = address(1);
    address internal bob = address(2);
    address internal jim = address(4);
    address internal owner = address(3);
    JUSDExchange jusdExchange;
    MockJOJODealer public jojoDealer;
    function setUp() public {
        jusd = new JUSD(6);
        usdc = new MockERC20(2000e6);
        jusdExchange = new JUSDExchange(address(usdc), address(jusd));
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(jim, "Jim");
        vm.label(owner, "Owner");
        usdc.transfer(alice, 2000e6);
        jusd.mint(10000e6);
        jusd.transfer(address(jusdExchange), 10000e6);
    }
    function testExchangeSuccess() public {
        vm.startPrank(alice);
        usdc.approve(address(jusdExchange), 1000e6);
        jusdExchange.buyJUSD(1000e6, alice);
        assertEq(jusd.balanceOf(alice), 1000e6);
        assertEq(usdc.balanceOf(alice), 1000e6);
    }
    function testExchangeSuccessClose() public {
        jusdExchange.closeExchange();
        vm.startPrank(alice);
        usdc.approve(address(jusdExchange), 1000e6);
        cheats.expectRevert("NOT_ALLOWED_TO_EXCHANGE");
        jusdExchange.buyJUSD(1000e6, alice);
        vm.stopPrank();
        jusdExchange.openExchange();
        vm.startPrank(alice);
        usdc.approve(address(jusdExchange), 1000e6);
        jusdExchange.buyJUSD(1000e6, alice);
    }
}