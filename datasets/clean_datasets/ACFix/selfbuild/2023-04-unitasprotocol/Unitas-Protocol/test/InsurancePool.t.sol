pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/InsurancePool.sol";
import "./mocks/MockERC20Token.sol";
import "./utils/Functions.sol";
contract InsurancePoolTest is Test {
    using stdStorage for StdStorage;
    InsurancePool insurancePool;
    MockERC20Token mockUSDT;
    address immutable Guardian = vm.addr(0x1);
    address immutable userA = vm.addr(0x2);
    address immutable governor = vm.addr(0x3);
    address immutable timelock = vm.addr(0x4);
    function setUp() public {
        insurancePool = new InsurancePool(governor, Guardian, timelock);
        mockUSDT = new MockERC20Token('USD Tether', 'USDT', 6);
    }
    function testDepositCollateral_ShouldPass_WhenIsGuardian() public {
        deal(address(mockUSDT), Guardian, 100e6);
        vm.startPrank(Guardian);
        mockUSDT.approve(address(insurancePool), 100e6);
        insurancePool.depositCollateral(address(mockUSDT), 100e6);
        vm.stopPrank();
        assertEq(mockUSDT.balanceOf(Guardian), 0);
        assertEq(insurancePool.getCollateral(address(mockUSDT)), 100e6);
    }
    function testWithdrawCollateral_ShouldPass_WhenIsGuardian() public {
        testDepositCollateral_ShouldPass_WhenIsGuardian();
        vm.prank(Guardian);
        insurancePool.withdrawCollateral(address(mockUSDT), 100e6);
        assertEq(mockUSDT.balanceOf(Guardian), 100e6);
        assertEq(insurancePool.getCollateral(address(mockUSDT)), 0);
    }
    function testReceivePortfolio_ShouldPass_WhenIsPortfolio() public {
        testSendPortfolio_ShouldPass_WhenIsTimelock();
        uint256 portfolioAmount = insurancePool.getPortfolio(address(mockUSDT));
        address portfolioManager = Guardian;
        vm.startPrank(portfolioManager);
        mockUSDT.approve(address(insurancePool), portfolioAmount);
        insurancePool.receivePortfolio(address(mockUSDT), portfolioAmount);
        vm.stopPrank();
        assertEq(mockUSDT.balanceOf(portfolioManager), 0);
    }
    function testSendPortfolio_ShouldPass_WhenIsTimelock() public {
        testDepositCollateral_ShouldPass_WhenIsGuardian();
        uint256 portfolioAmount = insurancePool.getCollateral(address(mockUSDT));
        address portfolioManager = Guardian;
        vm.prank(timelock);
        insurancePool.sendPortfolio(address(mockUSDT), portfolioManager, portfolioAmount);
        assertEq(mockUSDT.balanceOf(portfolioManager), portfolioAmount);
    }
    function testDepositCollateral_ShouldFail_WhenNotGuardian() public {
        deal(address(mockUSDT), userA, 100e6);
        vm.startPrank(userA);
        mockUSDT.approve(address(insurancePool), 100e6);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        insurancePool.depositCollateral(address(mockUSDT), 100e6);
        vm.stopPrank();
    }
    function testDepositCollateral_ShouldFail_WhenAmountIsZero() public {
        deal(address(mockUSDT), Guardian, 100e6);
        vm.startPrank(Guardian);
        vm.expectRevert(_errorMessage(Errors.AMOUNT_INVALID));
        insurancePool.depositCollateral(address(mockUSDT), 0);
        vm.stopPrank();
    }
    function testWithdrawCollateral_ShouldFail_WhenNotWithdrawer() public {
        testDepositCollateral_ShouldPass_WhenIsGuardian();
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotWithdrawer(address)", userA)
        );
        insurancePool.withdrawCollateral(address(mockUSDT), 100e6);
        vm.stopPrank();
    }
    function testWithdrawCollateral_ShouldFail_WhenAmountIsZero() public {
        testDepositCollateral_ShouldPass_WhenIsGuardian();
        vm.startPrank(Guardian);
        vm.expectRevert(_errorMessage(Errors.AMOUNT_INVALID));
        insurancePool.withdrawCollateral(address(mockUSDT), 0);
        vm.stopPrank();
    }
    function testWithdrawCollateral_ShouldFail_WhenCollateralIsInsufficient() public {
        testDepositCollateral_ShouldPass_WhenIsGuardian(); 
        vm.startPrank(Guardian);
        vm.expectRevert(_errorMessage(Errors.POOL_BALANCE_INSUFFICIENT));
        insurancePool.withdrawCollateral(address(mockUSDT), 100e6 + 1);
        vm.stopPrank();
    }
    function testReceivePortfolio_ShouldFail_WhenNotPortfolio() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotPortfolio(address)", userA)
        );
        vm.prank(userA);
        insurancePool.receivePortfolio(address(mockUSDT), 100e6);
    }
    function testSendPortfolio_ShouldFail_WhenNotTimelock() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotTimelock(address)", userA)
        );
        vm.prank(userA);
        insurancePool.sendPortfolio(address(mockUSDT), Guardian, 100e6);
    }
    function testSendPortfolio_ShouldFail_WhenNotPortfolio() public {
        vm.expectRevert(
            abi.encodeWithSignature("NotPortfolio(address)", userA)
        );
        vm.prank(timelock);
        insurancePool.sendPortfolio(address(mockUSDT), userA, 100e6);
    }
}