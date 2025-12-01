pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
import "../../src/Impl/flashloanImpl/FlashLoanLiquidate.sol";
contract JUSDBankClearReserveTest is JUSDBankInitTest {
    function testClearReserve() public {
        mockToken1.transfer(alice, 10e18);
        mockToken2.transfer(bob, 10e8);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        vm.warp(1000);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        vm.warp(2000);
        jusdBank.borrow(3000e6, alice, false);
        vm.stopPrank();
        jusdBank.delistReserve(address(mockToken1));
        vm.startPrank(bob);
        FlashLoanLiquidate flashLoanLiquidate = new FlashLoanLiquidate(
            address(jusdBank),
            address(jusdExchange),
            address(USDC),
            address(jusd),
            insurance
        );
        bytes memory data = swapContract.getSwapData(
            10e18,
            address(mockToken1)
        );
        bytes memory param = abi.encode(
            swapContract,
            swapContract,
            address(bob),
            data
        );
        bytes memory afterParam = abi.encode(
            address(flashLoanLiquidate),
            param
        );
        DataTypes.LiquidateData memory liq = jusdBank.liquidate(
            alice,
            address(mockToken1),
            bob,
            10e18,
            afterParam,
            1000e6
        );
        uint256 bobDeposit = jusdBank.getDepositBalance(
            address(mockToken1),
            bob
        );
        uint256 aliceDeposit = jusdBank.getDepositBalance(
            address(mockToken1),
            alice
        );
        uint256 bobBorrow = jusdBank.getBorrowBalance(bob);
        uint256 aliceBorrow = jusdBank.getBorrowBalance(alice);
        uint256 insuranceUSDC = IERC20(USDC).balanceOf(insurance);
        uint256 aliceUSDC = IERC20(USDC).balanceOf(alice);
        uint256 bobUSDC = IERC20(USDC).balanceOf(bob);
        console.log("liquidate amount", liq.actualCollateral);
        console.log("bob deposit", bobDeposit);
        console.log("alice deposit", aliceDeposit);
        console.log("bob borrow", bobBorrow);
        console.log("alice borrow", aliceBorrow);
        console.log("bob usdc", bobUSDC);
        console.log("alice usdc", aliceUSDC);
        console.log("insurance balance", insuranceUSDC);
        vm.stopPrank();
    }
    function testClearMock2() public {
        mockToken1.transfer(alice, 10e18);
        mockToken2.transfer(alice, 1e8);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        jusdBank.borrow(3000e6, alice, false);
        vm.stopPrank();
        jusdBank.delistReserve(address(mockToken1));
        vm.startPrank(alice);
        mockToken2.approve(address(jusdBank), 1e8);
        jusdBank.deposit(alice, address(mockToken2), 1e8, alice);
        cheats.expectRevert("AFTER_WITHDRAW_ACCOUNT_IS_NOT_SAFE");
        jusdBank.withdraw(address(mockToken2), 1e8, alice, false);
        uint256 maxWithdrawBTC = jusdBank.getMaxWithdrawAmount(
            address(mockToken2),
            alice
        );
        uint256 maxMint = jusdBank.getDepositMaxMintAmount(alice);
        assertEq(maxMint, 14000e6);
        assertEq(maxWithdrawBTC, 78571428);
        vm.stopPrank();
    }
    function testClearAndRegister() public {
        mockToken1.transfer(alice, 10e18);
        vm.startPrank(address(jusdBank));
        jusd.transfer(alice, 1000e6);
        vm.stopPrank();
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        vm.warp(1000);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        vm.warp(2000);
        jusdBank.borrow(3000e6, alice, false);
        vm.stopPrank();
        vm.warp(3000);
        jusdBank.delistReserve(address(mockToken1));
        vm.warp(4000);
        jusdBank.relistReserve(address(mockToken1));
        vm.startPrank(alice);
        jusdBank.withdraw(address(mockToken1), 1e18, alice, false);
        vm.stopPrank();
        assertEq(jusdBank.getDepositBalance(address(mockToken1), alice), 9e18);
    }
}