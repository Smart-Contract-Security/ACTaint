pragma solidity 0.8.10;
import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {MockERC20} from "./utils/mocks/MockERC20.sol";
import {MockERC4626} from "./utils/mocks/MockERC4626.sol";
contract ERC4626Test is DSTestPlus {
    MockERC20 underlying;
    MockERC4626 vault;
    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);
        vault = new MockERC4626(underlying, "Mock Token Vault", "vwTKN");
    }
    function invariantMetadata() public {
        assertEq(vault.name(), "Mock Token Vault");
        assertEq(vault.symbol(), "vwTKN");
        assertEq(vault.decimals(), 18);
    }
    function testMetadata(string calldata name, string calldata symbol) public {
        MockERC4626 vlt = new MockERC4626(underlying, name, symbol);
        assertEq(vlt.name(), name);
        assertEq(vlt.symbol(), symbol);
        assertEq(address(vlt.asset()), address(underlying));
    }
    function testSingleDepositWithdraw(uint128 amount) public {
        if (amount == 0) amount = 1;
        uint256 aliceUnderlyingAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceUnderlyingAmount);
        hevm.prank(alice);
        underlying.approve(address(vault), aliceUnderlyingAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceUnderlyingAmount);
        uint256 alicePreDepositBal = underlying.balanceOf(alice);
        hevm.prank(alice);
        uint256 aliceShareAmount = vault.deposit(aliceUnderlyingAmount, alice);
        assertEq(vault.afterDepositHookCalledCounter(), 1);
        assertEq(aliceUnderlyingAmount, aliceShareAmount);
        assertEq(vault.previewWithdraw(aliceShareAmount), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal - aliceUnderlyingAmount);
        hevm.prank(alice);
        vault.withdraw(aliceUnderlyingAmount, alice, alice);
        assertEq(vault.beforeWithdrawHookCalledCounter(), 1);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal);
    }
    function testSingleMintRedeem(uint128 amount) public {
        if (amount == 0) amount = 1;
        uint256 aliceShareAmount = amount;
        address alice = address(0xABCD);
        underlying.mint(alice, aliceShareAmount);
        hevm.prank(alice);
        underlying.approve(address(vault), aliceShareAmount);
        assertEq(underlying.allowance(alice, address(vault)), aliceShareAmount);
        uint256 alicePreDepositBal = underlying.balanceOf(alice);
        hevm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(aliceShareAmount, alice);
        assertEq(vault.afterDepositHookCalledCounter(), 1);
        assertEq(aliceShareAmount, aliceUnderlyingAmount);
        assertEq(vault.previewWithdraw(aliceShareAmount), aliceUnderlyingAmount);
        assertEq(vault.previewDeposit(aliceUnderlyingAmount), aliceShareAmount);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceUnderlyingAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(underlying.balanceOf(alice), alicePreDepositBal - aliceUnderlyingAmount);
        hevm.prank(alice);
        vault.redeem(aliceShareAmount, alice, alice);
        assertEq(vault.beforeWithdrawHookCalledCounter(), 1);
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
        hevm.prank(alice);
        underlying.approve(address(vault), 4000);
        assertEq(underlying.allowance(alice, address(vault)), 4000);
        underlying.mint(bob, 7001);
        hevm.prank(bob);
        underlying.approve(address(vault), 7001);
        assertEq(underlying.allowance(bob, address(vault)), 7001);
        hevm.prank(alice);
        uint256 aliceUnderlyingAmount = vault.mint(2000, alice);
        uint256 aliceShareAmount = vault.previewDeposit(aliceUnderlyingAmount);
        assertEq(vault.afterDepositHookCalledCounter(), 1);
        assertEq(aliceShareAmount, 2000);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), aliceUnderlyingAmount);
        assertEq(vault.convertToShares(aliceUnderlyingAmount), vault.balanceOf(alice));
        assertEq(aliceUnderlyingAmount, 2000);
        assertEq(vault.totalSupply(), aliceShareAmount);
        assertEq(vault.totalAssets(), aliceUnderlyingAmount);
        hevm.prank(bob);
        uint256 bobShareAmount = vault.deposit(4000, bob);
        uint256 bobUnderlyingAmount = vault.previewWithdraw(bobShareAmount);
        assertEq(vault.afterDepositHookCalledCounter(), 2);
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
        underlying.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalSupply(), preMutationShareBal);
        assertEq(vault.totalAssets(), preMutationBal + mutationUnderlyingAmount);
        assertEq(vault.balanceOf(alice), aliceShareAmount);
        assertEq(
            vault.convertToAssets(vault.balanceOf(alice)),
            aliceUnderlyingAmount + (mutationUnderlyingAmount / 3) * 1
        );
        assertEq(vault.balanceOf(bob), bobShareAmount);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), bobUnderlyingAmount + (mutationUnderlyingAmount / 3) * 2);
        hevm.prank(alice);
        vault.deposit(2000, alice);
        assertEq(vault.totalSupply(), 7333);
        assertEq(vault.balanceOf(alice), 3333);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 4999);
        assertEq(vault.balanceOf(bob), 4000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 6000);
        hevm.prank(bob);
        vault.mint(2000, bob);
        assertEq(vault.totalSupply(), 9333);
        assertEq(vault.balanceOf(alice), 3333);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 5000);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 9000);
        assertEq(underlying.balanceOf(alice), 0);
        assertEq(underlying.balanceOf(bob), 0);
        assertEq(vault.totalAssets(), 14001);
        underlying.mint(address(vault), mutationUnderlyingAmount);
        assertEq(vault.totalAssets(), 17001);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 6071);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);
        hevm.prank(alice);
        vault.redeem(1333, alice, alice);
        assertEq(underlying.balanceOf(alice), 2428);
        assertEq(vault.totalSupply(), 8000);
        assertEq(vault.totalAssets(), 14573);
        assertEq(vault.balanceOf(alice), 2000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        assertEq(vault.balanceOf(bob), 6000);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 10929);
        hevm.prank(bob);
        vault.withdraw(2929, bob, bob);
        assertEq(underlying.balanceOf(bob), 2929);
        assertEq(vault.totalSupply(), 6392);
        assertEq(vault.totalAssets(), 11644);
        assertEq(vault.balanceOf(alice), 2000);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 3643);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8000);
        hevm.prank(alice);
        vault.withdraw(3643, alice, alice);
        assertEq(underlying.balanceOf(alice), 6071);
        assertEq(vault.totalSupply(), 4392);
        assertEq(vault.totalAssets(), 8001);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertEq(vault.balanceOf(bob), 4392);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 8001);
        hevm.prank(bob);
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
        hevm.prank(alice);
        underlying.approve(address(vault), 1e18);
        hevm.prank(bob);
        underlying.approve(address(vault), 1e18);
        hevm.prank(alice);
        vault.deposit(1e18, bob);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(alice), 0);
        hevm.prank(bob);
        vault.mint(1e18, alice);
        assertEq(vault.balanceOf(alice), 1e18);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(bob), 0);
        hevm.prank(alice);
        vault.redeem(1e18, bob, alice);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 1e18);
        assertEq(underlying.balanceOf(bob), 1e18);
        hevm.prank(bob);
        vault.withdraw(1e18, alice, bob);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(underlying.balanceOf(alice), 1e18);
    }
}