pragma solidity ^0.8.17;
import {Errors} from "../../utils/Errors.sol";
import {BaseTest} from "../utils/BaseTest.sol";
contract LendingFlowTest is BaseTest {
    function setUp() public {
        setupContracts();
    }
    function testDepositEth(uint64 amt) public {
        cheats.assume(amt > 10 ** (18 - 2));
        cheats.deal(lender, amt);
        cheats.prank(lender);
        lEth.depositEth{value: amt}();
        assertEq(lender.balance, 0);
        assertEq(weth.balanceOf(address(lEth)), amt);
        assertGe(lEth.convertToAssets(lEth.balanceOf(lender)), amt);
    }
    function testWithdrawEth(uint64 amt) public {
        testDepositEth(amt);
        uint shares = lEth.balanceOf(lender);
        cheats.prank(lender);
        lEth.redeemEth(shares);
        assertEq(lender.balance, amt);
        assertEq(lEth.balanceOf(lender), 0);
        assertEq(address(lEth).balance, 0);
    }
    function testDepositERC20(uint64 amt) public {
        cheats.assume(amt > 10 ** (18 - 2));
        erc20.mint(lender, amt);
        cheats.startPrank(lender);
        erc20.approve(address(lErc20), type(uint).max);
        lErc20.deposit(amt, lender);
        cheats.stopPrank();
        assertEq(erc20.balanceOf(lender), 0);
        assertEq(erc20.balanceOf(address(lErc20)), amt);
        assertGe(lErc20.convertToAssets(lErc20.balanceOf(lender)), amt);
    }
    function testWithdrawERC20(uint64 amt) public {
        cheats.assume(amt > 10 ** (18 - 2));
        testDepositERC20(amt);
        uint shares = lErc20.balanceOf(lender);
        cheats.prank(lender);
        lErc20.redeem(shares, lender, lender);
        assertEq(erc20.balanceOf(lender), amt);
        assertEq(erc20.balanceOf(address(lErc20)), 0);
        assertEq(lErc20.balanceOf(lender), 0);
    }
    function testDepositMaxSupplyError(uint64 supply, uint64 depositAmt) public {
        cheats.assume(supply < depositAmt && depositAmt > 10 ** (18 - 2));
        erc20.mint(lender, depositAmt);
        lErc20.updateMaxSupply(supply);
        cheats.startPrank(lender);
        erc20.approve(address(lErc20), type(uint).max);
        cheats.expectRevert(Errors.MaxSupply.selector);
        lErc20.deposit(depositAmt, lender);
        cheats.stopPrank();
    }
}