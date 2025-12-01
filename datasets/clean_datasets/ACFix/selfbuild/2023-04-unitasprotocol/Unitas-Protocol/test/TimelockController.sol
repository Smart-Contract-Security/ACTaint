pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/ERC20Token.sol";
import "../src/TimelockController.sol";
contract VoteTest is Test {
    ERC20Token xUSD1; 
    TimelockController timelock;
    address Admin = vm.addr(0x1);
    address A = vm.addr(0x2);
    address B = vm.addr(0x3);
    function setUp() public {
        xUSD1 = new ERC20Token("xUSD1", "xUSD1", address(this), address(this), address(this));
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        timelock = new TimelockController(86400,proposers,executors,address(this));
        xUSD1.setMinter(address(timelock), address(msg.sender));
    }
    function testTimelock() public {
        emit log_named_decimal_uint("xUSD1 balance", xUSD1.balanceOf(address(this)), 18);
        bytes memory payload = abi.encodeWithSignature("mint(address,uint256)", address(this), 20000000);
        timelock.schedule(address(xUSD1), 0, payload, 0x0, 0x0, 86400);
        vm.warp(86401);
        timelock.execute(address(xUSD1), 0, payload, 0x0, 0x0);
        emit log_named_decimal_uint("xUSD1 balance", xUSD1.balanceOf(address(this)), 18);
    }
}