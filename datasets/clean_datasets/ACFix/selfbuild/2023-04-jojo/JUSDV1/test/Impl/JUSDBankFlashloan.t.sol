pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
import "../../src/Impl/flashloanImpl/FlashLoanRepay.sol";
import "../../src/Impl/JUSDExchange.sol";
import "../mocks/MockFlashloan.sol";
import "../../src/Testsupport/SupportsSWAP.sol";
import "../mocks/MockFlashloan2.sol";
import "../mocks/MockFlashloan3.sol";
contract JUSDBankFlashloanTest is JUSDBankInitTest {
    function testFlashloanWithdrawAmountIsTooBig() public {
        MockFlashloan mockFlashloan = new MockFlashloan();
        mockToken1.transfer(alice, 5e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        bytes memory test = "just a test";
        cheats.expectRevert("WITHDRAW_AMOUNT_IS_TOO_BIG");
        jusdBank.flashLoan(
            address(mockFlashloan),
            address(mockToken1),
            6e18,
            alice,
            test
        );
        vm.stopPrank();
    }
    function testFlashloanWithdrawAmountIsZero() public {
        MockFlashloan mockFlashloan = new MockFlashloan();
        mockToken1.transfer(alice, 5e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        bytes memory test = "just a test";
        cheats.expectRevert("WITHDRAW_AMOUNT_IS_ZERO");
        jusdBank.flashLoan(
            address(mockFlashloan),
            address(mockToken1),
            0,
            alice,
            test
        );
        vm.stopPrank();
    }
    function testFlashloanSuccess() public {
        MockFlashloan mockFlashloan = new MockFlashloan();
        mockToken1.transfer(alice, 5e18);
        mockToken2.transfer(address(mockFlashloan), 10e8);
        vm.startPrank(address(mockFlashloan));
        mockToken2.approve(address(jusdBank), 10e8);
        vm.stopPrank();
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        bytes memory test = "just a test";
        jusdBank.flashLoan(
            address(mockFlashloan),
            address(mockToken1),
            5e18,
            alice,
            test
        );
        vm.stopPrank();
        address[] memory collateralList = jusdBank.getUserCollateralList(alice);
        assertEq(collateralList.length, 1);
        assertEq(jusdBank.getDepositBalance(address(mockToken1), alice), 0);
        assertEq(
            jusdBank.getIfHasCollateral(alice, address(mockToken1)),
            false
        );
        assertEq(jusdBank.getIfHasCollateral(alice, address(mockToken2)), true);
        assertEq(jusdBank.getDepositBalance(address(mockToken2), alice), 5e8);
        assertEq(mockToken2.balanceOf(address(mockFlashloan)), 5e8);
        assertEq(mockToken1.balanceOf(bob), 5e18);
    }
    function testFlashloan2() public {
        MockFlashloan2 mockFlashloan2 = new MockFlashloan2();
        mockToken1.transfer(alice, 5e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        jusdBank.borrow(2000e6, alice, false);
        bytes memory test = "just a test";
        cheats.expectRevert("AFTER_FLASHLOAN_ACCOUNT_IS_NOT_SAFE");
        jusdBank.flashLoan(
            address(mockFlashloan2),
            address(mockToken1),
            5e18,
            alice,
            test
        );
        vm.stopPrank();
    }
    function testFlashloan3() public {
        MockFlashloan3 mockFlashloan3 = new MockFlashloan3();
        mockToken1.transfer(alice, 5e18);
        mockToken2.transfer(address(mockFlashloan3), 10e8);
        vm.startPrank(address(mockFlashloan3));
        mockToken2.approve(address(jusdBank), 10e8);
        vm.stopPrank();
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 5e18);
        jusdBank.deposit(alice, address(mockToken1), 5e18, alice);
        bytes memory test = "just a test";
        cheats.expectRevert(
            "ReentrancyGuard: Withdraw or Borrow or Liquidate flashLoan reentrant call"
        );
        jusdBank.flashLoan(
            address(mockFlashloan3),
            address(mockToken1),
            1e18,
            alice,
            test
        );
        vm.stopPrank();
    }
    function testFlashloanRepayFK() public {
        MockERC20 usdc = new MockERC20(4000e18);
        SupportsSWAP swapContract = new SupportsSWAP(
            address(usdc),
            address(mockToken1),
            address(jojoOracle1)
        );
        IERC20(usdc).transfer(address(swapContract), 4000e18);
        JUSDExchange jusdExchange = new JUSDExchange(
            address(usdc),
            address(jusd)
        );
        jusd.mint(5000e6);
        IERC20(jusd).transfer(address(jusdExchange), 5000e6);
        FlashLoanRepay flashloanRepay = new FlashLoanRepay(
            address(jusdBank),
            address(jusdExchange),
            address(usdc),
            address(jusd)
        );
        mockToken1.transfer(alice, 1e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 1e18);
        jusdBank.deposit(alice, address(mockToken1), 1e18, alice);
        jusdBank.borrow(300e6, alice, false);
        bytes memory data = swapContract.getSwapData(1e18, address(mockToken1));
        bytes memory param = abi.encode(
            swapContract,
            swapContract,
            1000e6,
            data
        );
        jusdBank.flashLoan(
            address(flashloanRepay),
            address(mockToken1),
            1e18,
            alice,
            param
        );
        assertEq(IERC20(usdc).balanceOf(alice), 700e6);
        assertEq(jusdBank.getBorrowBalance(alice), 0);
        assertEq(IERC20(mockToken1).balanceOf(alice), 0);
        assertEq(IERC20(mockToken1).balanceOf(address(swapContract)), 1e18);
        vm.stopPrank();
    }
    function testFlashloanRepayExchangeIsClose() public {
        MockERC20 usdc = new MockERC20(4000e18);
        SupportsSWAP swapContract = new SupportsSWAP(
            address(usdc),
            address(mockToken1),
            address(jojoOracle1)
        );
        IERC20(usdc).transfer(address(swapContract), 4000e18);
        JUSDExchange jusdExchange = new JUSDExchange(
            address(usdc),
            address(jusd)
        );
        jusd.mint(5000e6);
        IERC20(jusd).transfer(address(jusdExchange), 5000e6);
        FlashLoanRepay flashloanRepay = new FlashLoanRepay(
            address(jusdBank),
            address(jusdExchange),
            address(usdc),
            address(jusd)
        );
        jusdExchange.closeExchange();
        mockToken1.transfer(alice, 1e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 1e18);
        jusdBank.deposit(alice, address(mockToken1), 1e18, alice);
        jusdBank.borrow(300e6, alice, false);
        bytes memory data = swapContract.getSwapData(1e16, address(mockToken1));
        bytes memory param = abi.encode(swapContract, swapContract, 10e6, data);
        cheats.expectRevert("NOT_ALLOWED_TO_EXCHANGE");
        jusdBank.flashLoan(
            address(flashloanRepay),
            address(mockToken1),
            1e16,
            alice,
            param
        );
        vm.stopPrank();
    }
    function testFlashloanRepayAmountLessBorrowBalance() public {
        MockERC20 usdc = new MockERC20(4000e18);
        SupportsSWAP swapContract = new SupportsSWAP(
            address(usdc),
            address(mockToken1),
            address(jojoOracle1)
        );
        IERC20(usdc).transfer(address(swapContract), 4000e18);
        JUSDExchange jusdExchange = new JUSDExchange(
            address(usdc),
            address(jusd)
        );
        jusd.mint(5000e6);
        IERC20(jusd).transfer(address(jusdExchange), 5000e6);
        FlashLoanRepay flashloanRepay = new FlashLoanRepay(
            address(jusdBank),
            address(jusdExchange),
            address(usdc),
            address(jusd)
        );
        mockToken1.transfer(alice, 1e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 1e18);
        jusdBank.deposit(alice, address(mockToken1), 1e18, alice);
        jusdBank.borrow(300e6, alice, false);
        bytes memory data = swapContract.getSwapData(1e15, address(mockToken1));
        bytes memory param = abi.encode(swapContract, swapContract, 1e6, data);
        jusdBank.flashLoan(
            address(flashloanRepay),
            address(mockToken1),
            1e15,
            alice,
            param
        );
        assertEq(jusdBank.getBorrowBalance(alice), 299e6);
        vm.stopPrank();
    }
    function testFlashloanRepayRevert() public {
        MockERC20 usdc = new MockERC20(4000e18);
        SupportsSWAP swapContract = new SupportsSWAP(
            address(usdc),
            address(mockToken1),
            address(jojoOracle1)
        );
        IERC20(usdc).transfer(address(swapContract), 2e6);
        JUSDExchange jusdExchange = new JUSDExchange(
            address(usdc),
            address(jusd)
        );
        jusd.mint(5000e6);
        IERC20(jusd).transfer(address(jusdExchange), 5000e6);
        FlashLoanRepay flashloanRepay = new FlashLoanRepay(
            address(jusdBank),
            address(jusdExchange),
            address(usdc),
            address(jusd)
        );
        mockToken1.transfer(alice, 3e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 3e18);
        jusdBank.deposit(alice, address(mockToken1), 3e18, alice);
        jusdBank.borrow(300e6, alice, false);
        bytes memory data = swapContract.getSwapData(3e18, address(mockToken1));
        bytes memory param = abi.encode(
            swapContract,
            swapContract,
            3000e6,
            data
        );
        cheats.expectRevert("ERC20: transfer amount exceeds balance");
        jusdBank.flashLoan(
            address(flashloanRepay),
            address(mockToken1),
            3e18,
            alice,
            param
        );
        vm.stopPrank();
    }
}