pragma solidity ^0.8.17;
import {Errors} from "../../utils/Errors.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {IAccount} from "../../interface/core/IAccount.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IControllerFacade} from "controller/core/IControllerFacade.sol";
contract AccountManagerTest is BaseTest {
    using FixedPointMathLib for uint;
    address account;
    address public owner = cheats.addr(1);
    function setUp() public {
        setupContracts();
        account = openAccount(owner);
    }
    function testApproveAuthError(
        address spender,
        address token,
        uint96 value
    )
        public
    {
        cheats.expectRevert(Errors.AccountOwnerOnly.selector);
        accountManager.approve(account, token, spender, value);
    }
    function testLiquidateHealthyAccount(
        uint96 depositAmt,
        uint96 borrowAmt
    )
        public
    {
        cheats.assume(borrowAmt > 10 ** (18 - 2));
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        deposit(owner, account, address(0), depositAmt);
        borrow(owner, account, address(weth), borrowAmt);
        cheats.expectRevert(Errors.AccountNotLiquidatable.selector);
        accountManager.liquidate(account);
    }
    function testSettle(uint96 depositAmt, uint96 borrowAmt) public {
        cheats.assume(borrowAmt > 10 ** (18 - 2));
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        deposit(owner, account, address(0), depositAmt);
        deposit(owner, account, address(erc20), depositAmt);
        borrow(owner, account, address(weth), borrowAmt);
        borrow(owner, account, address(erc20), borrowAmt);
        cheats.prank(owner);
        accountManager.settle(account);
        assertEq(account.balance, depositAmt);
        assertEq(erc20.balanceOf(account), depositAmt);
        assertEq(weth.balanceOf(address(lEth)), borrowAmt);
        assertEq(erc20.balanceOf(address(lErc20)), borrowAmt);
    }
    function testSettleAuthError() public {
        cheats.expectRevert(Errors.AccountOwnerOnly.selector);
        accountManager.settle(account);
    }
}