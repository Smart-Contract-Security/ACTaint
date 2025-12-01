pragma solidity 0.8.11;
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { FixedMath } from "../external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { YT } from "../tokens/YT.sol";
import { GYTManager } from "../modules/GYTManager.sol";
import { Periphery } from "../Periphery.sol";
import { Hevm } from "./test-helpers/Hevm.sol";
import { TestHelper } from "./test-helpers/TestHelper.sol";
contract DividerMock {}
contract GYTsManager is TestHelper {
    using FixedMath for uint256;
    using FixedMath for uint128;
    function testFuzzCantJoinIfInvalidMaturity(uint128 balance) public {
        uint256 maturity = block.timestamp - 1 days;
        try alice.doJoin(address(adapter), maturity, balance) {
            fail();
        } catch (bytes memory error) {
            assertEq0(error, abi.encodeWithSelector(Errors.InvalidMaturity.selector));
        }
    }
    function testFuzzCantJoinIfSeriesDoesntExists(uint128 balance) public {
        uint256 maturity = getValidMaturity(2021, 10);
        try alice.doJoin(address(adapter), maturity, balance) {
            fail();
        } catch (bytes memory error) {
            assertEq0(error, abi.encodeWithSelector(Errors.SeriesDoesNotExist.selector));
        }
    }
    function testFuzzCantJoinIfNotEnoughYT(uint128 balance) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = sponsorSampleSeries(address(alice), maturity);
        if (calculateAmountToIssue(balance) == 0) return;
        hevm.warp(block.timestamp + 1 days);
        bob.doApprove(address(yt), address(bob.gYTManager()));
        try bob.doJoin(address(adapter), maturity, balance) {
            fail();
        } catch (bytes memory error) {}
    }
    function testFuzzCantJoinIfNotEnoughYieldAllowance(uint128 balance) public {
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = sponsorSampleSeries(address(alice), maturity);
        if (calculateAmountToIssue(balance) == 0) return;
        hevm.warp(block.timestamp + 1 days);
        bob.doIssue(address(adapter), maturity, balance);
        uint256 yieldBalance = YT(yt).balanceOf(address(bob));
        try bob.doJoin(address(adapter), maturity, yieldBalance) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "TRANSFER_FROM_FAILED");
        }
    }
    function testCantJoinAfterFirstGYTNotEnoughTargetBalance() public {
        adapter.setScale(0.1e18); 
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = sponsorSampleSeries(address(alice), maturity);
        uint256 bbalance = target.balanceOf(address(bob));
        bbalance = bbalance - calculateExcess(bbalance, maturity, yt);
        bob.doIssue(address(adapter), maturity, bbalance);
        uint256 bobYieldBalance = YT(yt).balanceOf(address(bob));
        bob.doApprove(address(yt), address(bob.gYTManager()));
        bob.doJoin(address(adapter), maturity, bobYieldBalance);
        uint256 bobGyieldBalance = ERC20(bob.gYTManager().gyields(address(yt))).balanceOf(address(bob));
        assertEq(bobGyieldBalance, bobYieldBalance);
        adapter.setScale(0); 
        uint256 abalance = target.balanceOf(address(alice));
        hevm.warp(block.timestamp + 1 days);
        alice.doIssue(address(adapter), maturity, abalance);
        alice.doApprove(address(yt), address(bob.gYTManager()));
        hevm.warp(block.timestamp + 20 days);
        uint256 aliceYieldBalance = YT(yt).balanceOf(address(alice));
        alice.doCollect(address(yt));
        alice.doTransfer(address(target), address(bob), target.balanceOf(address(alice)));
        try alice.doJoin(address(adapter), maturity, aliceYieldBalance) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "TRANSFER_FROM_FAILED");
        }
    }
    function testFuzzCantExitIfSeriesDoesntExists(uint128 balance) public {
        uint256 maturity = getValidMaturity(2021, 10);
        try alice.doExit(address(adapter), maturity, balance) {
            fail();
        } catch (bytes memory error) {
            assertEq0(error, abi.encodeWithSelector(Errors.SeriesDoesNotExist.selector));
        }
    }
    function testFuzzExitFirstGYT(uint128 balance) public {
        balance = 100;
        Periphery newPeriphery = new Periphery(
            address(divider),
            address(poolManager),
            address(spaceFactory),
            address(balancerVault)
        );
        divider.setPeriphery(address(newPeriphery));
        alice.setPeriphery(newPeriphery);
        bob.setPeriphery(newPeriphery);
        periphery = newPeriphery;
        poolManager.setIsTrusted(address(periphery), true);
        alice.doApprove(address(stake), address(periphery));
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = sponsorSampleSeries(address(alice), maturity);
        if (calculateAmountToIssue(balance) == 0) return;
        bob.doIssue(address(adapter), maturity, balance);
        bob.doApprove(address(yt), address(bob.gYTManager()));
        uint256 yieldBalanceBefore = YT(yt).balanceOf(address(bob));
        bob.doJoin(address(adapter), maturity, yieldBalanceBefore);
        uint256 tBalanceBefore = target.balanceOf(address(bob));
        uint256 gyieldBalanceBefore = ERC20(bob.gYTManager().gyields(address(yt))).balanceOf(address(bob));
        bob.doExit(address(adapter), maturity, gyieldBalanceBefore);
        uint256 gyieldBalanceAfter = ERC20(bob.gYTManager().gyields(address(yt))).balanceOf(address(bob));
        uint256 yieldBalanceAfter = YT(yt).balanceOf(address(bob));
        uint256 tBalanceAfter = target.balanceOf(address(bob));
        assertEq(gyieldBalanceAfter, 0);
        assertEq(yieldBalanceAfter, yieldBalanceBefore);
        assertEq(tBalanceBefore, tBalanceAfter);
    }
}