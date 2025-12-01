pragma solidity ^0.8.17;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {IAccount} from "../../interface/core/IAccount.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
contract RepayInParts is BaseTest {
    using FixedPointMathLib for uint;
    address public account;
    address public borrower = cheats.addr(1);
    function setUp() public {
        setupContracts();
        account = openAccount(borrower);
    }
    function testRepayInParts1(uint96 depositAmt, uint96 borrowAmt, uint96 repayAmt)
        public
    {
        cheats.assume(borrowAmt > repayAmt && repayAmt > 10 ** (18 - 2));
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        deposit(borrower, account, address(erc20), depositAmt);
        borrow(borrower, account, address(erc20), borrowAmt);
        cheats.roll(block.number + 100);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), repayAmt);
        cheats.roll(block.number + 100);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), type(uint).max);
        assertEq(riskEngine.getBorrows(account), 0);
        assertEq(lErc20.getBorrows(), 0);
    }
    function testRepayInParts2(uint96 depositAmt, uint96 borrowAmt, uint96 borrow1)
        public
    {
        cheats.assume(borrowAmt > borrow1 && borrow1 > 10 ** (18 - 2));
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        address lender = address(5);
        erc20.mint(lender, borrowAmt);
        cheats.startPrank(lender);
        erc20.approve(address(lErc20), type(uint).max);
        lErc20.deposit(borrowAmt, lender);
        cheats.stopPrank();
        deposit(borrower, account, address(erc20), depositAmt);
        cheats.startPrank(borrower);
        if (lErc20.previewDeposit(borrow1) > 0)
            accountManager.borrow(account, address(erc20), borrow1);
        cheats.stopPrank();
        cheats.roll(block.number + 10);
        erc20.mint(account, type(uint128).max);
        cheats.startPrank(borrower);
        if (lErc20.previewDeposit(borrowAmt - borrow1) > 0)
            accountManager.borrow(account, address(erc20), borrowAmt - borrow1);
        cheats.stopPrank();
        cheats.roll(block.number + 10);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), type(uint).max);
        assertEq(riskEngine.getBorrows(account), 0);
        assertEq(lErc20.getBorrows(), 0);
    }
    function testRepayInParts3(
        uint96 depositAmt,
        uint96 borrowAmt,
        uint96 borrow1,
        uint96 repayAmt
    )
        public
    {
        cheats.assume(borrowAmt > repayAmt && repayAmt > 10 ** (18 - 2));
        cheats.assume(borrowAmt > borrow1);
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        address lender = address(5);
        erc20.mint(lender, borrowAmt);
        cheats.startPrank(lender);
        erc20.approve(address(lErc20), type(uint).max);
        lErc20.deposit(borrowAmt, lender);
        cheats.stopPrank();
        deposit(borrower, account, address(erc20), depositAmt);
        cheats.startPrank(borrower);
        if (lErc20.previewDeposit(borrow1) > 0)
            accountManager.borrow(account, address(erc20), borrow1);
        cheats.stopPrank();
        cheats.roll(block.number + 10);
        erc20.mint(account, type(uint128).max);
        cheats.startPrank(borrower);
        if (lErc20.previewDeposit(borrowAmt - borrow1) > 0)
            accountManager.borrow(account, address(erc20), borrowAmt - borrow1);
        cheats.stopPrank();
        cheats.roll(block.number + 10);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), repayAmt);
        cheats.roll(block.number + 10);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), type(uint).max);
        assertEq(riskEngine.getBorrows(account), 0);
        assertEq(lErc20.getBorrows(), 0);
    }
    function testRepayInParts4(
        uint96 depositAmt,
        uint96 borrowAmt,
        uint96 borrow1
    )
        public
    {
        cheats.assume(borrowAmt > borrow1 && borrow1 > 10 ** (18 - 2));
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        uint repayAmt = borrow1 / 2;
        cheats.assume(repayAmt > 0);
        address lender = address(5);
        erc20.mint(lender, borrowAmt);
        cheats.startPrank(lender);
        erc20.approve(address(lErc20), type(uint).max);
        lErc20.deposit(borrowAmt, lender);
        cheats.stopPrank();
        deposit(borrower, account, address(erc20), depositAmt);
        cheats.startPrank(borrower);
        if (lErc20.previewDeposit(borrow1) > 0)
            accountManager.borrow(account, address(erc20), borrow1);
        cheats.stopPrank();
        cheats.roll(block.number + 10);
        erc20.mint(account, type(uint128).max);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), repayAmt);
        cheats.roll(block.number + 10);
        cheats.startPrank(borrower);
        if (lErc20.previewDeposit(borrowAmt - borrow1) > 0)
            accountManager.borrow(account, address(erc20), borrowAmt - borrow1);
        cheats.stopPrank();
        cheats.roll(block.number + 10);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), type(uint).max);
        assertEq(riskEngine.getBorrows(account), 0);
        assertEq(lErc20.getBorrows(), 0);
    }
    function testRepayInParts10()
        public
    {
        uint depositAmt = 5e17;
        uint borrowAmt = 5e17;
        uint repayAmt = 2e17;
        deposit(borrower, account, address(erc20), depositAmt);
        borrow(borrower, account, address(erc20), borrowAmt);
        cheats.roll(block.number + 23);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), repayAmt);
        cheats.roll(block.number + 15);
        cheats.prank(borrower);
        accountManager.repay(account, address(erc20), type(uint).max);
        assertEq(riskEngine.getBorrows(account), 0);
        assertEq(lErc20.getBorrows(), 0);
    }
}