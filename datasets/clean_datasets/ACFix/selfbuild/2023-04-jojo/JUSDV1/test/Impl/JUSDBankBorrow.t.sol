pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
import "../mocks/MockJOJODealerRevert.sol";
import "../mocks/MockChainLink15000.sol";
contract JUSDBankBorrowTest is JUSDBankInitTest {
    MockJOJODealerRevert public jojoDealerRevert = new MockJOJODealerRevert();
    function testBorrowJUSDSuccess() public {
        mockToken1.transfer(alice, 100e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        jusdBank.borrow(5000e6, alice, false);
        uint256 jusdBalance = jusdBank.getBorrowBalance(alice);
        assertEq(jusdBalance, 5000e6);
        assertEq(jusd.balanceOf(alice), 5000e6);
        assertEq(mockToken1.balanceOf(alice), 90e18);
        assertEq(jusdBank.getDepositBalance(address(mockToken1), alice), 10e18);
        vm.stopPrank();
    }
    function testBorrow2CollateralJUSDSuccess() public {
        mockToken1.transfer(alice, 100e18);
        mockToken2.transfer(alice, 100e8);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        mockToken2.approve(address(jusdBank), 10e8);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        jusdBank.deposit(alice, address(mockToken2), 10e8, alice);
        jusdBank.borrow(6000e6, alice, false);
        uint256 jusdBalance = jusdBank.getBorrowBalance(alice);
        assertEq(jusdBalance, 6000e6);
        assertEq(jusd.balanceOf(alice), 6000e6);
        assertEq(mockToken1.balanceOf(alice), 90e18);
        assertEq(jusdBank.getDepositBalance(address(mockToken1), alice), 10e18);
        assertEq(jusdBank.getDepositBalance(address(mockToken2), alice), 10e8);
        vm.stopPrank();
    }
    function testBorrowJUSDtRateSuccess() public {
        mockToken1.transfer(alice, 100e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        vm.warp(1000);
        jusdBank.borrow(5000e6, alice, false);
        uint256 jusdBalance = jusdBank.getBorrowBalance(alice);
        assertEq(jusdBalance, 5000e6);
        assertEq(jusd.balanceOf(alice), 5000e6);
        assertEq(mockToken1.balanceOf(alice), 90e18);
        assertEq(jusdBank.getDepositBalance(address(mockToken1), alice), 10e18);
        vm.stopPrank();
    }
    function testBorrowJUSDFailMaxMintAmount() public {
        mockToken1.transfer(alice, 100e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        cheats.expectRevert("AFTER_BORROW_ACCOUNT_IS_NOT_SAFE");
        jusdBank.borrow(8001e6, alice, false);
        vm.stopPrank();
    }
    function testBorrowJUSDFailPerAccount() public {
        mockToken1.transfer(alice, 100e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        cheats.expectRevert("EXCEED_THE_MAX_BORROW_AMOUNT_PER_ACCOUNT");
        jusdBank.borrow(100001e6, alice, false);
        vm.stopPrank();
    }
    function testBorrowJUSDFailTotalAmount() public {
        mockToken1.transfer(alice, 200e18);
        mockToken1.transfer(bob, 200e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 200e18);
        jusdBank.deposit(alice, address(mockToken1), 200e18, alice);
        jusdBank.borrow(100000e6, alice, false);
        vm.stopPrank();
        vm.startPrank(bob);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(bob, address(mockToken1), 10e18, bob);
        cheats.expectRevert("EXCEED_THE_MAX_BORROW_AMOUNT_TOTAL");
        jusdBank.borrow(5000e6, bob, false);
        vm.stopPrank();
    }
    function testBorrowDepositToJOJO() public {
        mockToken1.transfer(alice, 100e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        jusdBank.borrow(5000e6, alice, true);
        vm.stopPrank();
    }
    function testBorrowDepositToJOJORevert() public {
        mockToken1.transfer(alice, 100e18);
        jusdBank.updateJOJODealer(address(jojoDealerRevert));
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        cheats.expectRevert("test For revert");
        jusdBank.borrow(5000e6, alice, true);
        vm.stopPrank();
    }
    function testDepositTooMany() public {
        jusdBank.updateReserveParam(
            address(mockToken1),
            8e17,
            2300e18,
            230e18,
            100000e6
        );
        jusdBank.updateMaxBorrowAmount(200000e6, 300000e18);
        mockToken1.transfer(alice, 200e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 200e18);
        jusdBank.deposit(alice, address(mockToken1), 200e18, alice);
        cheats.expectRevert("AFTER_BORROW_ACCOUNT_IS_NOT_SAFE");
        jusdBank.borrow(200000e6, alice, false);
        jusdBank.borrow(100000e6, alice, false);
        jusdBank.withdraw(
            address(mockToken1),
            75000000000000000000,
            alice,
            false
        );
        vm.stopPrank();
    }
    function testGetDepositMaxData() public {
        jusdBank.updateReserveParam(
            address(mockToken1),
            8e17,
            2300e18,
            230e18,
            100000e18
        );
        jusdBank.updateReserveParam(
            address(mockToken2),
            8e17,
            2300e18,
            230e18,
            100000e18
        );
        jusdBank.updateMaxBorrowAmount(200000e18, 300000e18);
        mockToken1.transfer(alice, 10e18);
        mockToken2.transfer(alice, 1e8);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        mockToken2.approve(address(jusdBank), 1e8);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        jusdBank.deposit(alice, address(mockToken2), 1e8, alice);
        jusdBank.borrow(8000e6, alice, false);
        uint256 maxMint = jusdBank.getDepositMaxMintAmount(alice);
        console.log("max mint", maxMint);
    }
    function testDepositTooManyETH() public {
        jusdBank.updateReserveParam(
            address(mockToken1),
            8e17,
            2300e18,
            230e18,
            100000e6
        );
        jusdBank.updateReserveParam(
            address(mockToken2),
            8e17,
            2300e8,
            230e8,
            100000e6
        );
        jusdBank.updateRiskParam(address(mockToken1), 825e15, 5e16, 1e17);
        jusdBank.updateMaxBorrowAmount(200000e6, 300000e6);
        mockToken1.transfer(alice, 200e18);
        mockToken2.transfer(alice, 5e8);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 200e18);
        mockToken2.approve(address(jusdBank), 10e8);
        jusdBank.deposit(alice, address(mockToken1), 200e18, alice);
        jusdBank.deposit(alice, address(mockToken2), 5e8, alice);
        jusdBank.borrow(100000e6, alice, false);
        jusdBank.borrow(80000e6, alice, false);
        uint256 maxWithdrawMockToken1 = jusdBank.getMaxWithdrawAmount(
            address(mockToken1),
            alice
        );
        console.log(
            "max withdraw mockToken1 before fall",
            maxWithdrawMockToken1
        );
        uint256 maxWithdrawMockToken2 = jusdBank.getMaxWithdrawAmount(
            address(mockToken2),
            alice
        );
        console.log(
            "max withdraw mockToken2 before fall",
            maxWithdrawMockToken2
        );
        cheats.expectRevert("AFTER_BORROW_ACCOUNT_IS_NOT_SAFE");
        jusdBank.borrow(1e6, alice, false);
        assertEq(maxWithdrawMockToken1, 75000000000000000000);
        assertEq(maxWithdrawMockToken2, 375000000);
        vm.stopPrank();
        MockChainLink15000 btc15000 = new MockChainLink15000();
        JOJOOracleAdaptor jojoOracle15000 = new JOJOOracleAdaptor(
            address(btc15000),
            10,
            86400,
            address(usdcPrice)
        );
        jusdBank.updateOracle(address(mockToken2), address(jojoOracle15000));
        maxWithdrawMockToken1 = jusdBank.getMaxWithdrawAmount(
            address(mockToken1),
            alice
        );
        console.log("max withdraw mockToken1", maxWithdrawMockToken1);
        maxWithdrawMockToken2 = jusdBank.getMaxWithdrawAmount(
            address(mockToken2),
            alice
        );
        console.log("max withdraw mockToken2", maxWithdrawMockToken2);
        vm.startPrank(alice);
        cheats.expectRevert("AFTER_WITHDRAW_ACCOUNT_IS_NOT_SAFE");
        jusdBank.withdraw(
            address(mockToken1),
            75000000000000000000,
            alice,
            false
        );
        bool ifSafe = jusdBank.isAccountSafe(alice);
        uint256 borrowJUSD = jusdBank.getBorrowBalance(alice);
        uint256 depositAmount = jusdBank.getDepositMaxMintAmount(alice);
        console.log("borrow amount", borrowJUSD);
        console.log("depositAmount amount", depositAmount);
        console.log("alice safe?", ifSafe);
    }
}