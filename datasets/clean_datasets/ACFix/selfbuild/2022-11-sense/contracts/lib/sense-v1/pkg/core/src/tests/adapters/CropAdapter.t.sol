pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedMath } from "../../external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { BaseAdapter } from "../../adapters/abstract/BaseAdapter.sol";
import { ERC4626CropAdapter } from "../../adapters/abstract/erc4626/ERC4626CropAdapter.sol";
import { Divider } from "../../Divider.sol";
import { YT } from "../../tokens/YT.sol";
import { MockCropAdapter } from "../test-helpers/mocks/MockAdapter.sol";
import { MockFactory } from "../test-helpers/mocks/MockFactory.sol";
import { MockToken } from "../test-helpers/mocks/MockToken.sol";
import { MockTarget } from "../test-helpers/mocks/MockTarget.sol";
import { MockClaimer } from "../test-helpers/mocks/MockClaimer.sol";
import { TestHelper, MockTargetLike } from "../test-helpers/TestHelper.sol";
import { Constants } from "../test-helpers/Constants.sol";
contract CropAdapters is TestHelper {
    using FixedMath for uint256;
    function setUp() public virtual override {
        ISSUANCE_FEE = 0; 
        MAX_MATURITY = 52 weeks; 
        super.setUp();
        if (!is4626Target) adapter.setScale(1e18);
    }
    function testAdapterHasParams() public {
        MockToken underlying = new MockToken("Dai", "DAI", uDecimals);
        MockTargetLike target = MockTargetLike(
            deployMockTarget(address(underlying), "Compound Dai", "cDAI", tDecimals)
        );
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: ORACLE,
            stake: address(stake),
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            level: DEFAULT_LEVEL
        });
        MockCropAdapter cropAdapter = new MockCropAdapter(
            address(divider),
            address(target),
            !is4626Target ? target.underlying() : target.asset(),
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            adapterParams,
            address(reward)
        );
        (address oracle, address stake, uint256 stakeSize, uint256 minm, uint256 maxm, , , ) = adapter.adapterParams();
        assertEq(cropAdapter.reward(), address(reward));
        assertEq(cropAdapter.name(), "Compound Dai Adapter");
        assertEq(cropAdapter.symbol(), "cDAI-adapter");
        assertEq(cropAdapter.target(), address(target));
        assertEq(cropAdapter.underlying(), address(underlying));
        assertEq(cropAdapter.divider(), address(divider));
        assertEq(cropAdapter.rewardsRecipient(), Constants.REWARDS_RECIPIENT);
        assertEq(cropAdapter.ifee(), ISSUANCE_FEE);
        assertEq(stake, address(stake));
        assertEq(stakeSize, STAKE_SIZE);
        assertEq(minm, MIN_MATURITY);
        assertEq(maxm, MAX_MATURITY);
        assertEq(oracle, ORACLE);
        assertEq(cropAdapter.mode(), MODE);
        assertTrue(cropAdapter.isTrusted(address(divider)));
        assertTrue(cropAdapter.isTrusted(address(this)));
    }
    function testExtractToken() public {
        MockToken someReward = new MockToken("Some Reward", "SR", 18);
        someReward.mint(address(adapter), 1e18);
        assertEq(someReward.balanceOf(address(adapter)), 1e18);
        vm.expectEmit(true, true, true, true);
        emit RewardsClaimed(address(someReward), Constants.REWARDS_RECIPIENT, 1e18);
        assertEq(someReward.balanceOf(Constants.REWARDS_RECIPIENT), 0);
        vm.prank(address(0xfede));
        adapter.extractToken(address(someReward));
        assertEq(someReward.balanceOf(Constants.REWARDS_RECIPIENT), 1e18);
        (address target, address stake, ) = adapter.getStakeAndTarget();
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotSupported.selector));
        adapter.extractToken(address(stake));
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotSupported.selector));
        adapter.extractToken(address(target));
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenNotSupported.selector));
        adapter.extractToken(address(reward));
    }
    function testFuzzDistribution(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.expectEmit(true, true, true, false);
        emit Distributed(alice, address(reward), 0);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 0);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 0);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
    }
    function testFuzzSingleDistribution(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (100 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 0);
        reward.mint(address(adapter), 10 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        divider.issue(address(adapter), maturity, (100 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        divider.issue(address(adapter), maturity, (100 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        reward.mint(address(adapter), 10 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 10 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 20 * 10**rDecimals);
    }
    function testFuzzProportionalDistribution(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 0);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 0);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        divider.issue(address(adapter), maturity, (20 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        reward.mint(address(adapter), 30 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 0);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 80 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 50 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
    }
    function testFuzzSimpleDistributionAndCollect(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100);
        assertEq(reward.balanceOf(bob), 0);
        reward.mint(address(adapter), 60 * 10**rDecimals);
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(reward.balanceOf(bob), 24 * 10**rDecimals);
    }
    function testFuzzDistributionCollectAndTransferMultiStep(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100);
        assertEq(reward.balanceOf(bob), 0);
        reward.mint(address(adapter), 60 * 10**rDecimals);
        vm.warp(block.timestamp + 1 days);
        vm.prank(jim);
        divider.issue(address(adapter), maturity, (100 * tBal) / 100);
        vm.warp(block.timestamp + 1 days);
        reward.mint(address(adapter), 100 * 10**rDecimals);
        uint256 bytBal = ERC20(yt).balanceOf(bob);
        vm.prank(bob);
        MockToken(yt).transfer(jim, bytBal);
        assertApproxRewardBal(reward.balanceOf(bob), 44 * 10**rDecimals);
        assertApproxRewardBal(reward.balanceOf(jim), 50 * 10**rDecimals);
        YT(yt).collect();
        assertApproxRewardBal(reward.balanceOf(alice), 66 * 10**rDecimals);
        vm.warp(block.timestamp + 1 days);
        reward.mint(address(adapter), 100 * 10**rDecimals);
        vm.prank(jim);
        YT(yt).collect();
        assertApproxRewardBal(reward.balanceOf(jim), 120 * 10**rDecimals);
        YT(yt).collect();
        assertApproxRewardBal(reward.balanceOf(alice), 96 * 10**rDecimals);
    }
    function testFuzzCollectRewardSettleSeriesAndCheckTBalanceIsZero(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, tBal);
        uint256 airdrop = 1e18;
        reward.mint(address(adapter), airdrop);
        YT(yt).collect();
        assertTrue(adapter.tBalance(alice) > 0);
        reward.mint(address(adapter), airdrop);
        vm.warp(maturity);
        divider.settleSeries(address(adapter), maturity);
        YT(yt).collect();
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        uint256 collected = YT(yt).collect(); 
        assertEq(collected, 0);
    }
    function testFuzzReconcileMoreThanOnce(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        assertEq(reward.balanceOf(bob), 0);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](1);
        users[0] = bob;
        vm.expectEmit(true, false, false, false);
        emit Reconciled(bob, 0, maturity);
        adapter.reconcile(users, maturities);
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(reward.balanceOf(bob), 20 * 10**rDecimals);
    }
    function testFuzzGetMaturedSeriesRewardsIfReconcileAfterMaturity(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        assertEq(reward.balanceOf(bob), 0);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](1);
        users[0] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(reward.balanceOf(bob), 20 * 10**rDecimals);
    }
    function testFuzzCantDiluteRewardsIfReconciledInSingleDistribution(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 0);
        reward.mint(address(adapter), 10 * 10**rDecimals);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        reward.mint(address(adapter), 20 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.tBalance(alice), 200);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](1);
        users[0] = alice;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 200);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        uint256 newMaturity = getValidMaturity(2021, 11);
        periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, 50 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        reward.mint(address(adapter), 30 * 10**rDecimals);
        divider.issue(address(adapter), newMaturity, 10);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
    }
    function testFuzzCantDiluteRewardsIfReconciledAndCombineS1_YTsFirstI(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (40 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.prank(bob);
        YT(yt).collect();
        divider.issue(address(adapter), newMaturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
    }
    function testFuzzCantDiluteRewardsIfReconciledAndCombineS1_YTsFirstII(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, (120 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(alice), (120 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (80 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (80 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(newYt).collect();
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), (120 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), (80 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
    }
    function testFuzzCantDiluteRewardsIfReconciledAndCombineS1_YTsFirstIII(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, (30 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(alice), (30 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (20 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (20 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), (30 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), (20 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
    }
    function testFuzzCantDiluteRewardsIfReconciledAndCombineS1_YTsFirstIV(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), maturity, (100 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(alice), (100 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (0 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 0);
        divider.issue(address(adapter), newMaturity, (100 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(alice), (200 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (0 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 0);
        reward.mint(address(adapter), 10 * 10**rDecimals);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 10 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertEq(adapter.tBalance(alice), (200 * tBal) / 100);
        assertEq(adapter.reconciledAmt(alice), 0);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        adapter.reconcile(users, maturities);
        assertEq(adapter.tBalance(alice), (100 * tBal) / 100);
        assertEq(adapter.reconciledAmt(alice), (100 * tBal) / 100);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        assertEq(adapter.tBalance(alice), (100 * tBal) / 100);
        assertEq(adapter.reconciledAmt(alice), 0);
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(alice));
        assertApproxRewardBal(adapter.tBalance(alice), (0 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (0 * tBal) / 100);
    }
    function testFuzzCantDiluteRewardsIfReconciledInProportionalDistributionWithScaleChanges(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        is4626Target ? increaseScale(address(target)) : adapter.setScale(2e18);
        assertEq(adapter.scale(), 2e18);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (30 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (20 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (30 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (20 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (40 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 120 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 80 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(alice));
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        vm.startPrank(bob);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(bob));
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(bob));
        vm.stopPrank();
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
    }
    function testFuzzCantDiluteRewardsInProportionalDistributionWithScaleChangesAndCollectAfterReconcile(uint256 tBal)
        public
    {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        is4626Target ? increaseScale(address(target)) : adapter.setScale(2e18);
        assertEq(adapter.scale(), 2e18);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        assertEq(ERC20(reward).balanceOf(alice), 0);
        assertEq(ERC20(reward).balanceOf(bob), 0);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.totalTarget(), 0);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (40 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 90 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 60 * 10**rDecimals);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 120 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 80 * 10**rDecimals);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(alice));
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(alice));
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        vm.startPrank(bob);
        divider.combine(address(adapter), maturity, ERC20(yt).balanceOf(bob));
        divider.combine(address(adapter), newMaturity, ERC20(newYt).balanceOf(bob));
        vm.stopPrank();
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
    }
    function testFuzzDiluteRewardsIfNoReconcile(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        assertTrue(ERC20(yt).balanceOf(alice) > 0);
        assertTrue(adapter.tBalance(alice) > 0);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertEq(ERC20(yt).balanceOf(bob), 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(address(adapter)), 0);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (40 * tBal) / 100);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.prank(bob);
        YT(newYt).collect();
        assertTrue(ERC20(reward).balanceOf(bob) != 70 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertEq(ERC20(yt).balanceOf(alice), 0);
        assertEq(ERC20(yt).balanceOf(alice), 0);
    }
    function testFuzzDiluteRewardsIfLateReconcile(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100); 
        reward.mint(address(adapter), 50 * 10**rDecimals);
        YT(yt).collect();
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 30 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 20 * 10**rDecimals);
        assertTrue(ERC20(yt).balanceOf(alice) > 0);
        assertTrue(adapter.tBalance(alice) > 0);
        vm.warp(maturity + 1 seconds);
        divider.settleSeries(address(adapter), maturity);
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertEq(ERC20(yt).balanceOf(bob), 0);
        assertApproxRewardBal(ERC20(reward).balanceOf(address(adapter)), 0);
        uint256 newMaturity = getValidMaturity(2021, 11);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (40 * tBal) / 100);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.prank(bob);
        YT(newYt).collect();
        assertTrue(ERC20(reward).balanceOf(bob) != 70 * 10**rDecimals);
        assertApproxRewardBal(ERC20(reward).balanceOf(bob), 40 * 10**rDecimals);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = maturity;
        address[] memory users = new address[](1);
        users[0] = alice;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), (60 * tBal) / 100);
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        YT(yt).collect();
        assertApproxRewardBal(ERC20(reward).balanceOf(alice), 60 * 10**rDecimals);
        assertApproxRewardBal(ERC20(yt).balanceOf(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
    }
    function testFuzzReconcileSingleSeriesWhenTwoSeriesOverlap(uint256 tBal) public {
        assumeBounds(tBal);
        vm.warp(1609459200);
        uint256 maturity = getValidMaturity(2021, 12);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        divider.issue(address(adapter), maturity, (60 * tBal) / 100); 
        assertEq(reward.balanceOf(alice), 0);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(block.timestamp + 12 weeks); 
        uint256 newMaturity = getValidMaturity(2021, 7);
        (, address newYt) = periphery.sponsorSeries(address(adapter), newMaturity, true);
        divider.issue(address(adapter), newMaturity, 0);
        assertApproxRewardBal(reward.balanceOf(alice), 50 * 10**rDecimals);
        vm.prank(bob);
        divider.issue(address(adapter), newMaturity, (40 * tBal) / 100);
        assertApproxRewardBal(reward.balanceOf(bob), 0);
        reward.mint(address(adapter), 50 * 10**rDecimals);
        vm.warp(newMaturity + 1 seconds);
        divider.settleSeries(address(adapter), newMaturity);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), 0);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), (40 * tBal) / 100);
        uint256[] memory maturities = new uint256[](1);
        maturities[0] = newMaturity;
        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;
        adapter.reconcile(users, maturities);
        assertApproxRewardBal(adapter.tBalance(alice), (60 * tBal) / 100);
        assertApproxRewardBal(adapter.tBalance(bob), 0);
        assertApproxRewardBal(adapter.reconciledAmt(alice), 0);
        assertApproxRewardBal(adapter.reconciledAmt(bob), (40 * tBal) / 100);
        assertApproxRewardBal(reward.balanceOf(alice), 50 * 10**rDecimals);
        assertApproxRewardBal(reward.balanceOf(bob), 20 * 10**rDecimals);
        divider.issue(address(adapter), maturity, 0);
        assertApproxRewardBal(reward.balanceOf(alice), 80 * 10**rDecimals);
    }
    function test4626SetRewardsTokens() public {
        if (!is4626Target) return;
        ERC4626CropAdapter a = ERC4626CropAdapter(address(adapter));
        vm.expectEmit(true, false, false, true);
        emit RewardTokenChanged(address(0xfede));
        vm.prank(address(factory)); 
        a.setRewardToken(address(0xfede));
        assertEq(a.reward(), address(0xfede));
    }
    function testSetRewardsTokens() public {
        if (is4626Target) return;
        vm.expectEmit(true, false, false, true);
        emit RewardTokenChanged(address(0xfede));
        vm.prank(address(factory)); 
        adapter.setRewardToken(address(0xfede));
        assertEq(adapter.reward(), address(0xfede));
    }
    function testCantSetRewardTokens() public {
        if (is4626Target) return;
        vm.expectRevert("UNTRUSTED");
        adapter.setRewardToken(address(0xfede));
    }
    function test4626CantSetRewardTokens() public {
        if (!is4626Target) return;
        vm.expectRevert("UNTRUSTED");
        ERC4626CropAdapter a = ERC4626CropAdapter(address(adapter));
        a.setRewardToken(address(0xfede));
    }
    function testCantSetClaimer() public {
        vm.expectRevert("UNTRUSTED");
        vm.prank(address(0x4b1d));
        adapter.setClaimer(address(0x4b1d));
    }
    function testCanSetClaimer() public {
        vm.expectEmit(true, true, true, true);
        emit ClaimerChanged(address(1));
        vm.prank(address(factory));
        adapter.setClaimer(address(1));
        assertEq(adapter.claimer(), address(1));
        vm.prank(Constants.RESTRICTED_ADMIN);
        adapter.setClaimer(address(2));
        assertEq(adapter.claimer(), address(2));
    }
    function testFuzzSimpleDistributionAndCollectWithClaimer(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(reward);
        MockClaimer claimer = new MockClaimer(address(adapter), rewardTokens);
        vm.prank(Constants.RESTRICTED_ADMIN);
        adapter.setClaimer(address(claimer));
        divider.issue(address(adapter), maturity, (60 * tBal) / 100);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, (40 * tBal) / 100);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(address(adapter));
        assertEq(reward.balanceOf(bob), 0);
        vm.prank(bob);
        YT(yt).collect();
        assertApproxRewardBal(reward.balanceOf(bob), 24 * 10**rDecimals);
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(address(adapter));
        assertEq(tBalAfter, tBalBefore);
    }
    function testFuzzSimpleDistributionAndCollectWithClaimerReverts(uint256 tBal) public {
        assumeBounds(tBal);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(reward);
        MockClaimer claimer = new MockClaimer(address(adapter), rewardTokens);
        claimer.setTransfer(false); 
        vm.prank(Constants.RESTRICTED_ADMIN);
        adapter.setClaimer(address(claimer));
        divider.issue(address(adapter), maturity, (60 * tBal) / 100);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.BadContractInteration.selector));
        divider.issue(address(adapter), maturity, (40 * tBal) / 100);
    }
    function assumeBounds(uint256 tBal) internal {
        vm.assume(tBal > (10**(tDecimals - 1))); 
        vm.assume(tBal < MAX_TARGET / 3);
    }
    function assertApproxRewardBal(uint256 a, uint256 b) public {
        assertApproxEqAbs(a, b, 1500);
    }
    event Reconciled(address indexed usr, uint256 tBal, uint256 maturity);
    event ClaimerChanged(address indexed claimer);
    event Distributed(address indexed usr, address indexed token, uint256 amount);
    event RewardTokenChanged(address indexed reward);
    event RewardTokensChanged(address[] indexed rewardTokens);
    event RewardsClaimed(address indexed token, address indexed recipient, uint256 indexed amount);
}