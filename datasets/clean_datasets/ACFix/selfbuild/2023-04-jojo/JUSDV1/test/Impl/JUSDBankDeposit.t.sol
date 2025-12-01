pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
import "../mocks/MockToken.sol";
contract JUSDBankTest is JUSDBankInitTest {
    function testDepositSuccess() public {
        mockToken1.transfer(alice, 10e18);
        mockToken2.transfer(alice, 10e8);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        uint256 balance = jusdBank.getDepositBalance(
            address(mockToken1),
            alice
        );
        assertEq(balance, 5e18);
        assertEq(jusdBank.getBorrowBalance(msg.sender), 0);
        address[] memory userList = jusdBank.getUserCollateralList(alice);
        assertEq(userList[0], address(mockToken1));
        vm.stopPrank();
    }
    function testAll() public {
        mockToken1.transfer(alice, 10e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        jusdBank.borrow(1000e6, alice, false);
        jusdBank.borrow(1000e6, alice, false);
        jusd.approve(address(jusdBank), 2000e18);
        jusdBank.repay(1000e6, alice);
        jusdBank.repay(1000e6, alice);
        jusdBank.withdraw(address(mockToken1), 5e18, alice, false);
        jusdBank.withdraw(address(mockToken1), 5e18, alice, false);
        vm.stopPrank();
    }
    function testDepositToBobSuccess() public {
        mockToken1.transfer(alice, 10e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5);
        jusdBank.deposit(alice, address(mockToken1), 5, bob);
        uint256 balance = jusdBank.getDepositBalance(
            address(mockToken1),
            alice
        );
        assertEq(balance, 0);
        assertEq(jusdBank.getDepositBalance(address(mockToken1), bob), 5);
        vm.stopPrank();
    }
    function testDepositAmountIs0Fail() public {
        mockToken1.transfer(alice, 10e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5);
        cheats.expectRevert("DEPOSIT_AMOUNT_IS_ZERO");
        jusdBank.deposit(alice, address(mockToken1), 0, alice);
        vm.stopPrank();
    }
    function testDepositFailAmountMoreThanPerAccount() public {
        mockToken1.transfer(alice, 2031e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 2031e18);
        cheats.expectRevert("EXCEED_THE_MAX_DEPOSIT_AMOUNT_PER_ACCOUNT");
        jusdBank.deposit(alice, address(mockToken1), 2031e18, alice);
        vm.stopPrank();
    }
    function testDepositFailAmountMoreTotal() public {
        mockToken1.transfer(alice, 2030e18);
        mockToken1.transfer(bob, 2030e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 2030e18);
        jusdBank.deposit(alice, address(mockToken1), 2030e18, alice);
        vm.stopPrank();
        assertEq(
            jusdBank.getDepositBalance(address(mockToken1), alice),
            2030e18
        );
        vm.startPrank(bob);
        mockToken1.approve(address(jusdBank), 2030e18);
        cheats.expectRevert("EXCEED_THE_MAX_DEPOSIT_AMOUNT_TOTAL");
        jusdBank.deposit(bob, address(mockToken1), 2030e18, bob);
        vm.stopPrank();
    }
    function testDepositTokenNotInReserve() public {
        MockToken mk = new MockToken(100e18);
        mk.transfer(alice, 10e18);
        vm.startPrank(alice);
        mk.approve(address(jusdBank), 10e18);
        cheats.expectRevert("RESERVE_NOT_ALLOW_DEPOSIT");
        jusdBank.deposit(alice, address(mk), 10e18, alice);
        vm.stopPrank();
    }
}