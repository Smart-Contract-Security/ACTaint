pragma solidity ^0.8.17;
import {Errors} from "../../utils/Errors.sol";
import {BaseTest} from "../utils/BaseTest.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
contract AccountManagerDepositWithdrawTest is BaseTest {
    using FixedPointMathLib for uint;
    address account;
    address public owner = cheats.addr(1);
    function setUp() public {
        setupContracts();
        account = openAccount(owner);
    }
    function testDepositEthAuthError(uint96 value) public {
        cheats.expectRevert(Errors.AccountOwnerOnly.selector);
        accountManager.depositEth{value: value}(account);
    }
    function testWithdrawEth(
        uint96 depositAmt,
        uint96 borrowAmt,
        uint96 withdrawAmt
    )
        public
    {
        cheats.assume(borrowAmt > 10 ** (18 - 2));
        cheats.assume(depositAmt >= withdrawAmt);
        cheats.assume(
            (uint(depositAmt) + borrowAmt - withdrawAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        ); 
        deposit(owner, account, address(0), depositAmt);
        borrow(owner, account, address(weth), borrowAmt);
        cheats.prank(owner);
        accountManager.withdrawEth(account, withdrawAmt);
        assertEq(
            riskEngine.getBalance(account),
            uint(depositAmt) - uint(withdrawAmt) + uint(borrowAmt)
        );
    }
    function testWithdrawEthRiskEngineError(
        uint96 depositAmt,
        uint96 borrowAmt,
        uint96 withdrawAmt
    )
        public
    {
        cheats.assume(borrowAmt > 10 ** (18 - 2));
        cheats.assume(depositAmt >= withdrawAmt);
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        cheats.assume(
            (uint(depositAmt) + borrowAmt - withdrawAmt).divWadDown(borrowAmt) <=
            riskEngine.balanceToBorrowThreshold()
        ); 
        deposit(owner, account, address(0), depositAmt);
        borrow(owner, account, address(weth), borrowAmt);
        cheats.prank(owner);
        cheats.expectRevert(Errors.RiskThresholdBreached.selector);
        accountManager.withdrawEth(account, withdrawAmt);
    }
    function testWithdrawEthAuthError(uint96 value) public {
        cheats.expectRevert(Errors.AccountOwnerOnly.selector);
        accountManager.withdrawEth(account, value);
    }
    function testDepositAuthError(address token, uint96 value) public {
        cheats.expectRevert(Errors.AccountOwnerOnly.selector);
        accountManager.deposit(account, token, value);
    }
    function testDepositCollateralTypeError(address token, uint96 value)
        public
    {
        cheats.assume(token != address(0) && !isContract(token));
        cheats.prank(owner);
        cheats.expectRevert(Errors.CollateralTypeRestricted.selector);
        accountManager.deposit(account, token, value);
    }
    function testWithdraw(
        uint96 depositAmt,
        uint96 borrowAmt,
        uint96 withdrawAmt
    )
        public
    {
        cheats.assume(borrowAmt > 10 ** (18 - 2));
        cheats.assume(depositAmt >= withdrawAmt);
        cheats.assume(
            (uint(depositAmt) + borrowAmt - withdrawAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        ); 
        deposit(owner, account, address(erc20), depositAmt);
        borrow(owner, account, address(erc20), borrowAmt);
        cheats.prank(owner);
        accountManager.withdraw(account, address(erc20), withdrawAmt);
        assertEq(
            erc20.balanceOf(account),
            uint(depositAmt) - uint(withdrawAmt) + uint(borrowAmt)
        );
    }
    function testWithdrawRiskEngineError(
        uint96 depositAmt,
        uint96 borrowAmt,
        uint96 withdrawAmt
    )
        public
    {
        cheats.assume(borrowAmt > 10 ** (18 - 2));
        cheats.assume(depositAmt >= withdrawAmt);
        cheats.assume(
            (uint(depositAmt) + borrowAmt).divWadDown(borrowAmt) >
            riskEngine.balanceToBorrowThreshold()
        );
        cheats.assume(
            (uint(depositAmt) + borrowAmt - withdrawAmt).divWadDown(borrowAmt) <=
            riskEngine.balanceToBorrowThreshold()
        ); 
        deposit(owner, account, address(erc20), depositAmt);
        borrow(owner, account, address(erc20), borrowAmt);
        cheats.prank(owner);
        cheats.expectRevert(Errors.RiskThresholdBreached.selector);
        accountManager.withdraw(account, address(erc20), withdrawAmt);
    }
    function testWithdrawAuthError(address token, uint96 value) public {
        cheats.expectRevert(Errors.AccountOwnerOnly.selector);
        accountManager.withdraw(account, token, value);
    }
}