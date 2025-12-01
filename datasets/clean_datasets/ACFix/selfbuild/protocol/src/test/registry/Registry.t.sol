pragma solidity ^0.8.17;
import {Errors} from "../../utils/Errors.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {IRegistry} from "../../interface/core/IRegistry.sol";
contract RegistryTest is BaseTest {
    function setUp() public {
        setupContracts();
    }
    function testUpdateAccount(address account, address owner) public {
        cheats.prank(address(accountManager));
        registry.updateAccount(account, owner);
        assertEq(registry.ownerFor(account), owner);
    }
    function testUpdateAccountError(address account, address owner) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        registry.updateAccount(account, owner);
        assertEq(registry.ownerFor(account), address(0));
    }
    function testAddAccount(address account, address owner) public {
        cheats.prank(address(accountManager));
        registry.addAccount(account, owner);
        address[] memory accounts = registry.accountsOwnedBy(owner);
        assertEq(registry.ownerFor(account), owner);
        assertEq(account, accounts[accounts.length - 1]); 
    }
    function testAddAccountError(address account, address owner) public {
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        registry.addAccount(account, owner);
        assertEq(registry.ownerFor(account), address(0));
        assertEq(registry.getAllAccounts().length, 0);
    }
    function testCloseAccount(address account, address owner) public {
        testAddAccount(account, owner);
        cheats.prank(address(accountManager));
        registry.closeAccount(account);
        assertEq(registry.ownerFor(account), address(0));
    }
    function testCloseAccountError(address account, address owner) public {
        testAddAccount(account, owner);
        cheats.expectRevert(Errors.AccountManagerOnly.selector);
        registry.closeAccount(account);
        assertEq(registry.ownerFor(account), owner);
    }
    function testAccountsOwnedBy(
        address[3] calldata accounts,
        address owner
    ) public {
        testAddAccount(accounts[0], owner);
        testAddAccount(accounts[1], owner);
        testAddAccount(accounts[2], owner);
        address[] memory accountsFromRegistry = registry.accountsOwnedBy(owner);
        assertEq(accounts[0], accountsFromRegistry[0]);
        assertEq(accounts[1], accountsFromRegistry[1]);
        assertEq(accounts[2], accountsFromRegistry[2]);
    }
}