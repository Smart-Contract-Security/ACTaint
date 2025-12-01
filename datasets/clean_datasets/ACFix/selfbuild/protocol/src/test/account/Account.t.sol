pragma solidity ^0.8.17;
import {Errors} from "../../utils/Errors.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {IAccount} from "../../interface/core/IAccount.sol";
contract AccountTest is BaseTest {
    IAccount public account;
    address public owner = cheats.addr(1);
    function setUp() public {
        setupContracts();
        account = IAccount(openAccount(owner));
    }
    function testInitialize() public {
        cheats.expectRevert(Errors.ContractAlreadyInitialized.selector);
        account.init(address(accountManager));
    }
    function testAddAsset(address token) public {
        cheats.prank(address(accountManager));
        account.addAsset(token);
        assertEq(token, account.getAssets()[0]);
        assertTrue(account.hasAsset(token));
    }
    function testAddAssetError(address token) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        account.addAsset(token);
    }
    function testAddBorrow(address token) public {
        cheats.prank(address(accountManager));
        account.addBorrow(token);
        assertEq(token, account.getBorrows()[0]);
    }
    function testAddBorrowError(address token) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        account.addBorrow(token);
    }
    function testRemoveAsset(address token) public {
        testAddAsset(token);
        cheats.prank(address(accountManager));
        account.removeAsset(token);
        assertEq(0, account.getAssets().length);
        assertFalse(account.hasAsset(token));
    }
    function testRemoveNonExistingAsset(address token) public {
        cheats.prank(address(accountManager));
        account.removeAsset(token);
        assertEq(0, account.getAssets().length);
        assertFalse(account.hasAsset(token));
    }
    function testRemoveAssetError(address token) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        account.removeAsset(token);
    }
    function testRemoveBorrow(address token) public {
        testAddBorrow(token);
        cheats.prank(address(accountManager));
        account.removeBorrow(token);
        assertEq(0, account.getBorrows().length);
    }
    function testRemoveBorrowError(address token) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        account.removeBorrow(token);
    }
    function testHasNoDebt(address token) public {
        assertTrue(account.hasNoDebt());
        testAddBorrow(token);
        assertTrue(account.hasNoDebt() == false);
    }
    function testSweepTo(address user, uint96 amt) public {
        cheats.assume(amt != 0 && !isContract(user));
        testAddAsset(address(erc20));
        erc20.mint(address(account), amt);
        cheats.deal(address(account), amt);
        cheats.prank(address(accountManager));
        account.sweepTo(address(user));
        assertEq(erc20.balanceOf(address(account)), 0);
        assertEq(address(account).balance, 0);
        assertEq(erc20.balanceOf(address(user)), amt);
        assertGe(address(user).balance, amt);
        assertFalse(account.hasAsset(address(erc20)));
    }
    function testSweepToError(address user) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        account.sweepTo(address(user));
    }
}