pragma solidity ^0.8.4;
import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {AaveMiningMock} from "./mocks/AaveMiningMock.sol";
import {LendingPoolMock} from "./mocks/LendingPoolMock.sol";
import {AaveV2ERC4626} from "../../aave-v2/AaveV2ERC4626.sol";
import {IAaveMining} from "../../aave-v2/external/IAaveMining.sol";
import {ILendingPool} from "../../aave-v2/external/ILendingPool.sol";
import {AaveV2ERC4626Factory} from "../../aave-v2/AaveV2ERC4626Factory.sol";
contract AaveV2ERC4626Test is Test {
    address public constant rewardRecipient = address(0x01);
    ERC20Mock public aave;
    ERC20Mock public aToken;
    AaveV2ERC4626 public vault;
    ERC20Mock public underlying;
    IAaveMining public aaveMining;
    LendingPoolMock public lendingPool;
    AaveV2ERC4626Factory public factory;
    function setUp() public {
        aave = new ERC20Mock();
        aToken = new ERC20Mock();
        underlying = new ERC20Mock();
        lendingPool = new LendingPoolMock();
        aaveMining = new AaveMiningMock(address(aave));
        factory = new AaveV2ERC4626Factory(aaveMining, rewardRecipient, lendingPool);
        lendingPool.setReserveAToken(address(underlying), address(aToken));
        vault = AaveV2ERC4626(address(factory.createERC4626(underlying)));
    }
    function testSingleDepositWithdraw(uint128 amount) public {
        if (amount == 0) {
            amount = 1;
        }
        uint256 aliceUnderlyingAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceUnderlyingAmount);
        vm.prank(alice);
        underlying.approve(address(vault), aliceUnderlyingAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceUnderlyingAmount);
        uint256 alicePreDepositBal = underlying.balanceOf(alice);
        vm.prank(alice);
        uint256 aliceShareAmount = vault.deposit(aliceUnderlyingAmount, alice);
        assertEq(aliceUnderlyingAmount, aliceShareAmount);
        assertEq(vault.previewWithdraw(aliceShareAmount), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal - aliceUnderlyingAmount);
        vm.prank(alice);
        vault.withdraw(aliceUnderlyingAmount, alice, alice);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }
    function testSingleMintRedeem(uint128 amount) public {
        if (amount == 0) {
            amount = 1;
        }
        uint256 aliceShareAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceShareAmount);
        vm.prank(alice);
        underlying.approve(address(vault), aliceShareAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceShareAmount);
        uint256 alicePreDepositBal = underlying.balanceOf(alice);
        vm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(aliceShareAmount, alice);
        assertEq(aliceShareAmount, aliceUnderlyingAmount);
        assertEq(vault.previewWithdraw(aliceShareAmount), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceUnderlyingAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal - aliceUnderlyingAmount);
        vm.prank(alice);
        vault.redeem(aliceShareAmount, alice, alice);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }
    function testMultipleMintDepositRedeemWithdraw() public {
        address alice = address(0xABCD);
        address bob = address(0xDCBA);
        uint256 mutationUnderlyingAmount = 3000;
        underlying.mint(alice, 4000);
        vm.prank(alice);
        underlying.approve(address(vault), 4000);
        assertEq(underlying.allowance(alice, address(vault)), 4000);
        underlying.mint(bob, 7001);
        vm.prank(bob);
        underlying.approve(address(vault), 7001);
        assertEq(underlying.allowance(bob, address(vault)), 7001);
        vm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(2000, alice);
        uint256 aliceShareAmount = vault.previewDeposit(aliceUnderlyingAmount);
        assertEq(aliceShareAmount, 2000);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(vault.convertToShares(aliceUnderlyingAmount), vault.balanceOf(alice));
        assertEq(aliceUnderlyingAmount, 2000);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        vm.prank(bob);
        uint256 bobShareAmount = vault.deposit(4000, bob);
        uint256 bobUnderlyingAmount = vault.previewWithdraw(bobShareAmount);
        assertEq(bobUnderlyingAmount, 4000);
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), bobUnderlyingAmount);
        assertEq(vault.convertToShares(bobUnderlyingAmount), vault.balanceOf(bob));
        assertEq(bobShareAmount, bobUnderlyingAmount);
        uint256 preMutationShareBal = aliceShareAmount + bobShareAmount;
        uint256 preMutationBal = aliceUnderlyingAmount + bobUnderlyingAmount;
        assertEq(vault.totalSupply(), preMutationShareBal);
        assertEq(vault.totalAssets(), preMutationBal);
        assertEq(vault.totalSupply(), 6000);
        assertEq(vault.totalAssets(), 6000);
        underlying.mint(address(lendingPool), mutationUnderlyingAmount);
        aToken.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalSupply(), preMutationShareBal);
        assertEq(vault.totalAssets(), preMutationBal + mutationUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount + mutationUnderlyingAmount / 3 * 1
        );
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), bobUnderlyingAmount + mutationUnderlyingAmount / 3 * 2);
        vm.prank(alice);
        vault.deposit(2000, alice);
        assertEq(vault.totalSupply(), 7333);
        assertEq(vault.balanceOf(alice), 3333);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4999);
        assertEq(vault.balanceOf(bob), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);
        vm.prank(bob);
        vault.mint(2000, bob);
        assertEq(vault.totalSupply(), 9333);
        assertEq(vault.balanceOf(alice), 3333);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 5000);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 9000);
        assertEq(underlying.balanceOf(alice), 0);
        assertEq(underlying.balanceOf(bob), 0);
        assertEq(vault.totalAssets(), 14001);
        underlying.mint(address(lendingPool), mutationUnderlyingAmount);
        aToken.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalAssets(), 17001);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 6071);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);
        vm.prank(alice);
        vault.redeem(1333, alice, alice);
        assertEq(underlying.balanceOf(alice), 2428);
        assertEq(vault.totalSupply(), 8000);
        assertEq(vault.totalAssets(), 14573);
        assertEq(vault.balanceOf(alice), 2000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);
        vm.prank(bob);
        vault.withdraw(2929, bob, bob);
        assertEq(underlying.balanceOf(bob), 2929);
        assertEq(vault.totalSupply(), 6392);
        assertEq(vault.totalAssets(), 11644);
        assertEq(vault.balanceOf(alice), 2000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8000);
        vm.prank(alice);
        vault.withdraw(3643, alice, alice);
        assertEq(underlying.balanceOf(alice), 6071);
        assertEq(vault.totalSupply(), 4392);
        assertEq(vault.totalAssets(), 8001);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8001);
        vm.prank(bob);
        vault.redeem(4392, bob, bob);
        assertEq(underlying.balanceOf(bob), 10930);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 0);
        assertEq(underlying.balanceOf(address(vault)), 0);
    }
    function testFailDepositWithNotEnoughApproval() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);
        assertEq(underlying.allowance(address(this), address(vault)), 0.5e18);
        vault.deposit(1e18, address(this));
    }
    function testFailWithdrawWithNotEnoughUnderlyingAmount() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);
        vault.deposit(0.5e18, address(this));
        vault.withdraw(1e18, address(this), address(this));
    }
    function testFailRedeemWithNotEnoughShareAmount() public {
        underlying.mint(address(this), 0.5e18);
        underlying.approve(address(vault), 0.5e18);
        vault.deposit(0.5e18, address(this));
        vault.redeem(1e18, address(this), address(this));
    }
    function testFailWithdrawWithNoUnderlyingAmount() public {
        vault.withdraw(1e18, address(this), address(this));
    }
    function testFailRedeemWithNoShareAmount() public {
        vault.redeem(1e18, address(this), address(this));
    }
    function testFailDepositWithNoApproval() public {
        vault.deposit(1e18, address(this));
    }
    function testFailMintWithNoApproval() public {
        vault.mint(1e18, address(this));
    }
    function testFailDepositZero() public {
        vault.deposit(0, address(this));
    }
    function testMintZero() public {
        vault.mint(0, address(this));
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }
    function testFailRedeemZero() public {
        vault.redeem(0, address(this), address(this));
    }
    function testWithdrawZero() public {
        vault.withdraw(0, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }
    function testVaultInteractionsForSomeoneElse() public {
        address alice = address(0xABCD);
        address bob = address(0xDCBA);
        underlying.mint(alice, 1e18);
        underlying.mint(bob, 1e18);
        vm.prank(alice);
        underlying.approve(address(vault), 1e18);
        vm.prank(bob);
        underlying.approve(address(vault), 1e18);
        vm.prank(alice);
        vault.deposit(1e18, bob);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(alice), 0);
        vm.prank(bob);
        vault.mint(1e18, alice);
        assertEq(vault.balanceOf(alice), 1e18);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(bob), 0);
        vm.prank(alice);
        vault.redeem(1e18, bob, alice);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(bob), 1e18);
        vm.prank(bob);
        vault.withdraw(1e18, alice, bob);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(underlying.balanceOf(alice), 1e18);
    }
    function testFail_depositWhenPaused(uint128 amount) public {
        if (amount == 0) {
            amount = 1;
        }
        uint256 aliceUnderlyingAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceUnderlyingAmount);
        vm.prank(alice);
        underlying.approve(address(vault), aliceUnderlyingAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceUnderlyingAmount);
        lendingPool.setPaused(true);
        vm.prank(alice);
        vault.deposit(aliceUnderlyingAmount, alice);
    }
    function testFail_withdrawWhenPaused(uint128 amount) public {
        if (amount == 0) {
            amount = 1;
        }
        uint256 aliceUnderlyingAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceUnderlyingAmount);
        vm.prank(alice);
        underlying.approve(address(vault), aliceUnderlyingAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceUnderlyingAmount);
        vm.prank(alice);
        vault.deposit(aliceUnderlyingAmount, alice);
        lendingPool.setPaused(true);
        vm.prank(alice);
        vault.withdraw(aliceUnderlyingAmount, alice, alice);
    }
    function testFail_mintWhenPaused(uint128 amount) public {
        if (amount == 0) {
            amount = 1;
        }
        uint256 aliceShareAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceShareAmount);
        vm.prank(alice);
        underlying.approve(address(vault), aliceShareAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceShareAmount);
        lendingPool.setPaused(true);
        vm.prank(alice);
        vault.mint(aliceShareAmount, alice);
    }
    function testFail_redeemWhenPaused(uint128 amount) public {
        if (amount == 0) {
            amount = 1;
        }
        uint256 aliceShareAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceShareAmount);
        vm.prank(alice);
        underlying.approve(address(vault), aliceShareAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceShareAmount);
        vm.prank(alice);
        vault.mint(aliceShareAmount, alice);
        lendingPool.setPaused(true);
        vm.prank(alice);
        vault.redeem(aliceShareAmount, alice, alice);
    }
    function test_maxAmountsWhenPaused() public {
        address alice = address(0xABCD);
        lendingPool.setPaused(true);
        assertEq(vault.maxDeposit(alice), 0);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxMint(alice), 0);
        assertEq(vault.maxRedeem(alice), 0);
    }
    function test_claimRewards() public {
        vault.claimRewards();
        assertEqDecimal(aave.balanceOf(rewardRecipient), 1e18, 18);
    }
}