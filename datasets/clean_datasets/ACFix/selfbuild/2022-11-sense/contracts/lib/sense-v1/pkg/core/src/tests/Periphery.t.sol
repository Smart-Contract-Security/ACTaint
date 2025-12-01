pragma solidity 0.8.13;
import { FixedMath } from "../external/FixedMath.sol";
import { Periphery } from "../Periphery.sol";
import { Token } from "../tokens/Token.sol";
import { PoolManager, ComptrollerLike } from "@sense-finance/v1-fuse/src/PoolManager.sol";
import { BaseAdapter } from "../adapters/abstract/BaseAdapter.sol";
import { BaseFactory } from "../adapters/abstract/factories/BaseFactory.sol";
import { TestHelper, MockTargetLike } from "./test-helpers/TestHelper.sol";
import { MockToken } from "./test-helpers/mocks/MockToken.sol";
import { MockTarget } from "./test-helpers/mocks/MockTarget.sol";
import { MockAdapter, MockCropAdapter } from "./test-helpers/mocks/MockAdapter.sol";
import { MockFactory, MockCropFactory, Mock4626CropFactory } from "./test-helpers/mocks/MockFactory.sol";
import { MockPoolManager } from "./test-helpers/mocks/MockPoolManager.sol";
import { MockSpacePool } from "./test-helpers/mocks/MockSpace.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { BalancerPool } from "../external/balancer/Pool.sol";
import { BalancerVault } from "../external/balancer/Vault.sol";
import { Constants } from "./test-helpers/Constants.sol";
contract PeripheryTest is TestHelper {
    using FixedMath for uint256;
    function testDeployPeriphery() public {
        MockPoolManager poolManager = new MockPoolManager();
        address spaceFactory = address(2);
        address balancerVault = address(3);
        Periphery somePeriphery = new Periphery(address(divider), address(poolManager), spaceFactory, balancerVault);
        assertTrue(address(somePeriphery) != address(0));
        assertEq(address(Periphery(somePeriphery).divider()), address(divider));
        assertEq(address(Periphery(somePeriphery).poolManager()), address(poolManager));
        assertEq(address(Periphery(somePeriphery).spaceFactory()), address(spaceFactory));
        assertEq(address(Periphery(somePeriphery).balancerVault()), address(balancerVault));
    }
    function testSponsorSeries() public {
        uint256 maturity = getValidMaturity(2021, 10);
        vm.expectEmit(true, true, true, true);
        emit SeriesSponsored(address(adapter), maturity, address(this));
        (address pt, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        assertTrue(address(spaceFactory.pool()) != address(0));
        (PoolManager.SeriesStatus status, ) = PoolManager(address(poolManager)).sSeries(address(adapter), maturity);
        assertTrue(status == PoolManager.SeriesStatus.QUEUED);
    }
    function testSponsorSeriesWhenUnverifiedAdapter() public {
        divider.setPermissionless(true);
        MockCropAdapter adapter = new MockCropAdapter(
            address(divider),
            address(target),
            !is4626Target ? target.underlying() : target.asset(),
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            DEFAULT_ADAPTER_PARAMS,
            address(reward)
        );
        divider.addAdapter(address(adapter));
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        assertTrue(address(spaceFactory.pool()) != address(0));
        (PoolManager.SeriesStatus status, ) = PoolManager(address(poolManager)).sSeries(address(adapter), maturity);
        assertTrue(status == PoolManager.SeriesStatus.NONE);
    }
    function testSponsorSeriesWhenUnverifiedAdapterAndWithPoolFalse() public {
        divider.setPermissionless(true);
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: ORACLE,
            stake: address(stake),
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: 0,
            tilt: 0,
            level: DEFAULT_LEVEL
        });
        MockCropAdapter adapter = new MockCropAdapter(
            address(divider),
            address(target),
            !is4626Target ? target.underlying() : target.asset(),
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            adapterParams,
            address(reward)
        );
        divider.addAdapter(address(adapter));
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, address yt) = periphery.sponsorSeries(address(adapter), maturity, false);
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        assertTrue(address(spaceFactory.pool()) == address(0));
        (PoolManager.SeriesStatus status, ) = PoolManager(address(poolManager)).sSeries(address(adapter), maturity);
        assertTrue(status == PoolManager.SeriesStatus.NONE);
    }
    function testSponsorSeriesWhenPoolManagerZero() public {
        periphery.setPoolManager(address(0));
        periphery.verifyAdapter(address(adapter), true);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        assertTrue(yt != address(0));
    }
    function testFailSponsorSeriesWhenPoolManagerZero() public {
        periphery.setPoolManager(address(0));
        periphery.verifyAdapter(address(adapter), true);
        uint256 maturity = getValidMaturity(2021, 10);
        vm.expectEmit(false, false, false, false);
        emit SeriesQueued(address(1), 2, address(3));
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        assertTrue(yt != address(0));
    }
    function testDeployAdapter() public {
        MockToken underlying = new MockToken("New Underlying", "NT", 18);
        MockTargetLike newTarget = MockTargetLike(deployMockTarget(address(underlying), "New Target", "NT", 18));
        factory.supportTarget(address(newTarget), true);
        vm.expectEmit(false, false, false, false);
        emit AdapterDeployed(address(0));
        vm.expectEmit(false, false, false, false);
        emit AdapterVerified(address(0));
        vm.expectEmit(false, false, false, false);
        emit AdapterOnboarded(address(0));
        address[] memory rewardTokens;
        periphery.deployAdapter(address(factory), address(newTarget), abi.encode(rewardTokens));
        address cTarget = ComptrollerLike(poolManager.comptroller()).cTokensByUnderlying(address(newTarget));
        assertTrue(cTarget != address(0));
    }
    function testDeployCropAdapter() public {
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: address(stake),
            oracle: ORACLE,
            ifee: ISSUANCE_FEE,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            guard: DEFAULT_GUARD
        });
        address cropFactory;
        if (is4626Target) {
            cropFactory = address(
                new Mock4626CropFactory(
                    address(divider),
                    Constants.RESTRICTED_ADMIN,
                    Constants.REWARDS_RECIPIENT,
                    factoryParams,
                    address(reward)
                )
            );
        } else {
            cropFactory = address(
                new MockCropFactory(
                    address(divider),
                    Constants.RESTRICTED_ADMIN,
                    Constants.REWARDS_RECIPIENT,
                    factoryParams,
                    address(reward)
                )
            );
        }
        divider.setIsTrusted(cropFactory, true);
        periphery.setFactory(cropFactory, true);
        MockToken underlying = new MockToken("New Underlying", "NT", 18);
        MockTargetLike newTarget = MockTargetLike(deployMockTarget(address(underlying), "New Target", "NT", 18));
        MockFactory(cropFactory).supportTarget(address(newTarget), true);
        address[] memory rewardTokens;
        periphery.deployAdapter(cropFactory, address(newTarget), abi.encode(rewardTokens));
        address cTarget = ComptrollerLike(poolManager.comptroller()).cTokensByUnderlying(address(newTarget));
        assertTrue(cTarget != address(0));
    }
    function testDeployAdapterWhenPermissionless() public {
        divider.setPermissionless(true);
        MockToken underlying = new MockToken("New Underlying", "NT", 18);
        MockTargetLike newTarget = MockTargetLike(deployMockTarget(address(underlying), "New Target", "NT", 18));
        factory.supportTarget(address(newTarget), true);
        address[] memory rewardTokens;
        periphery.deployAdapter(address(factory), address(newTarget), abi.encode(rewardTokens));
        address cTarget = ComptrollerLike(poolManager.comptroller()).cTokensByUnderlying(address(newTarget));
        assertTrue(cTarget != address(0));
    }
    function testCantDeployAdapterIfTargetIsNotSupportedOnSpecificAdapter() public {
        MockToken someUnderlying = new MockToken("Some Underlying", "SU", 18);
        MockTargetLike someTarget = MockTargetLike(deployMockTarget(address(someUnderlying), "Some Target", "ST", 18));
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(reward);
        MockCropFactory someFactory = MockCropFactory(deployCropsFactory(address(someTarget), rewardTokens, false));
        vm.expectRevert(abi.encodeWithSelector(Errors.TargetNotSupported.selector));
        periphery.deployAdapter(address(factory), address(someTarget), abi.encode(rewardTokens));
        periphery.deployAdapter(address(someFactory), address(someTarget), abi.encode(rewardTokens));
    }
    function testCantDeployAdapterIfTargetIsNotSupported() public {
        address[] memory rewardTokens;
        MockToken someUnderlying = new MockToken("Some Underlying", "SU", 18);
        MockTargetLike newTarget = MockTargetLike(deployMockTarget(address(someUnderlying), "Some Target", "ST", 18));
        vm.expectRevert(abi.encodeWithSelector(Errors.TargetNotSupported.selector));
        periphery.deployAdapter(address(factory), address(newTarget), abi.encode(rewardTokens));
    }
    function testUpdatePoolManager() public {
        address oldPoolManager = address(periphery.poolManager());
        vm.record();
        address NEW_POOL_MANAGER = address(0xbabe);
        vm.expectEmit(true, false, false, true);
        emit PoolManagerChanged(oldPoolManager, NEW_POOL_MANAGER);
        periphery.setPoolManager(NEW_POOL_MANAGER);
        (, bytes32[] memory writes) = vm.accesses(address(periphery));
        assertEq(address(periphery.poolManager()), NEW_POOL_MANAGER);
        assertEq(writes.length, 1);
    }
    function testUpdateSpaceFactory() public {
        address oldSpaceFactory = address(periphery.spaceFactory());
        vm.record();
        address NEW_SPACE_FACTORY = address(0xbabe);
        vm.expectEmit(true, false, false, true);
        emit SpaceFactoryChanged(oldSpaceFactory, NEW_SPACE_FACTORY);
        periphery.setSpaceFactory(NEW_SPACE_FACTORY);
        (, bytes32[] memory writes) = vm.accesses(address(periphery));
        assertEq(address(periphery.spaceFactory()), NEW_SPACE_FACTORY);
        assertEq(writes.length, 1);
    }
    function testFuzzUpdatePoolManager(address lad) public {
        vm.record();
        vm.assume(lad != alice); 
        address NEW_POOL_MANAGER = address(0xbabe);
        vm.prank(lad);
        vm.expectRevert("UNTRUSTED");
        periphery.setPoolManager(NEW_POOL_MANAGER);
        (, bytes32[] memory writes) = vm.accesses(address(periphery));
        assertEq(writes.length, 0);
    }
    function testFuzzUpdateSpaceFactory(address lad) public {
        vm.record();
        vm.assume(lad != alice); 
        address NEW_SPACE_FACTORY = address(0xbabe);
        vm.prank(lad);
        vm.expectRevert("UNTRUSTED");
        periphery.setSpaceFactory(NEW_SPACE_FACTORY);
        (, bytes32[] memory writes) = vm.accesses(address(periphery));
        assertEq(writes.length, 0);
    }
    function testAdminOnboardFactory() public {
        address NEW_FACTORY = address(0xbabe);
        vm.expectEmit(true, false, false, true);
        emit FactoryChanged(NEW_FACTORY, true);
        assertTrue(!periphery.factories(NEW_FACTORY));
        periphery.setFactory(NEW_FACTORY, true);
        assertTrue(periphery.factories(NEW_FACTORY));
        vm.expectEmit(true, false, false, true);
        emit FactoryChanged(NEW_FACTORY, false);
        periphery.setFactory(NEW_FACTORY, false);
        assertTrue(!periphery.factories(NEW_FACTORY));
    }
    function testAdminOnboardVerifiedAdapter() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.verifyAdapter(address(otherAdapter), true);
        periphery.onboardAdapter(address(otherAdapter), true);
        (, bool enabled, , ) = divider.adapterMeta(address(otherAdapter));
        assertTrue(enabled);
    }
    function testAdminOnboardUnverifiedAdapter() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.onboardAdapter(address(otherAdapter), true);
        (, bool enabled, , ) = divider.adapterMeta(address(otherAdapter));
        assertTrue(enabled);
    }
    function testAdminOnboardVerifiedAdapterWhenPermissionlesss() public {
        divider.setPermissionless(true);
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.verifyAdapter(address(otherAdapter), true);
        periphery.onboardAdapter(address(otherAdapter), true);
        (, bool enabled, , ) = divider.adapterMeta(address(otherAdapter));
        assertTrue(enabled);
    }
    function testAdminOnboardUnverifiedAdapterWhenPermissionlesss() public {
        divider.setPermissionless(true);
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.onboardAdapter(address(otherAdapter), true);
        (, bool enabled, , ) = divider.adapterMeta(address(otherAdapter));
        assertTrue(enabled);
    }
    function testOnboardVerifiedAdapter() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.verifyAdapter(address(otherAdapter), true); 
        periphery.setIsTrusted(alice, false);
        vm.expectRevert(abi.encodeWithSelector(Errors.OnlyPermissionless.selector));
        periphery.onboardAdapter(address(otherAdapter), true);
    }
    function testOnboardUnverifiedAdapter() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.setIsTrusted(alice, false); 
        vm.expectRevert(abi.encodeWithSelector(Errors.OnlyPermissionless.selector));
        periphery.onboardAdapter(address(otherAdapter), true);
    }
    function testOnboardVerifiedAdapterWhenPermissionlesss() public {
        divider.setPermissionless(true);
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.verifyAdapter(address(otherAdapter), true); 
        periphery.setIsTrusted(alice, false);
        periphery.onboardAdapter(address(otherAdapter), true); 
        (, bool enabled, , ) = divider.adapterMeta(address(otherAdapter));
        assertTrue(enabled);
    }
    function testOnboardUnverifiedAdapterWhenPermissionlesss() public {
        divider.setPermissionless(true);
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.setIsTrusted(alice, false);
        periphery.onboardAdapter(address(otherAdapter), true); 
        (, bool enabled, , ) = divider.adapterMeta(address(otherAdapter));
        assertTrue(enabled);
    }
    function testReOnboardVerifiedAdapterAfterUpgradingPeriphery() public {
        Periphery somePeriphery = new Periphery(
            address(divider),
            address(poolManager),
            address(spaceFactory),
            address(balancerVault)
        );
        somePeriphery.onboardAdapter(address(adapter), false);
        assertTrue(periphery.verified(address(adapter)));
        (, bool enabled, , ) = divider.adapterMeta(address(adapter));
        assertTrue(enabled);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        assertTrue(yt != address(0));
    }
    function testAdminVerifyAdapter() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.verifyAdapter(address(otherAdapter), true); 
        assertTrue(periphery.verified(address(otherAdapter)));
    }
    function testAdminVerifyAdapterWhenPermissionless() public {
        divider.setPermissionless(true);
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.verifyAdapter(address(otherAdapter), true); 
        assertTrue(periphery.verified(address(otherAdapter)));
    }
    function testAdminVerifyAdapterWhenPoolManagerZero() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.setPoolManager(address(0));
        periphery.verifyAdapter(address(otherAdapter), true);
        assertTrue(periphery.verified(address(otherAdapter)));
    }
    function testFailAdminVerifyAdapterWhenPoolManagerZero() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.setPoolManager(address(0));
        vm.expectEmit(false, false, false, false);
        emit TargetAdded(address(1), address(2));
        periphery.verifyAdapter(address(otherAdapter), true);
        assertTrue(periphery.verified(address(otherAdapter)));
    }
    function testCantVerifyAdapterNonAdmin() public {
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.setIsTrusted(alice, false);
        vm.expectRevert("UNTRUSTED");
        periphery.verifyAdapter(address(otherAdapter), true); 
        assertTrue(!periphery.verified(address(otherAdapter)));
    }
    function testCantVerifyAdapterNonAdminWhenPermissionless() public {
        divider.setPermissionless(true);
        MockToken otherUnderlying = new MockToken("Usdc", "USDC", 18);
        MockTargetLike otherTarget = MockTargetLike(
            deployMockTarget(address(otherUnderlying), "Compound Usdc", "cUSDC", 18)
        );
        MockAdapter otherAdapter = MockAdapter(
            deployMockAdapter(address(divider), address(otherTarget), address(reward))
        );
        periphery.setIsTrusted(alice, false);
        vm.expectRevert("UNTRUSTED");
        periphery.verifyAdapter(address(otherAdapter), true); 
        assertTrue(!periphery.verified(address(otherAdapter)));
    }
    function testSwapTargetForPTs() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        addLiquidityToBalancerVault(maturity, 1000e18);
        uint256 ytBalBefore = ERC20(yt).balanceOf(alice);
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 uBal = tBal.fmul(adapter.scale());
        uint256 ptBal = uBal.fdiv(balancerVault.EXCHANGE_RATE());
        vm.expectEmit(true, false, false, false);
        emit Swapped(address(this), "0", adapter.target(), address(0), 0, 0, msg.sig);
        periphery.swapTargetForPTs(address(adapter), maturity, tBal, 0);
        assertEq(ytBalBefore, ERC20(yt).balanceOf(alice));
        assertEq(ptBalBefore + ptBal, ERC20(pt).balanceOf(alice));
    }
    function testSwapUnderlyingForPTs() public {
        uint256 uBal = 100 * (10**uDecimals);
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 scale = adapter.scale();
        uint256 tBal;
        if (!is4626Target) {
            tBal = uDecimals > tDecimals ? uBal.fdivUp(scale) / SCALING_FACTOR : uBal.fdivUp(scale) * SCALING_FACTOR;
        } else {
            tBal = target.previewDeposit(uBal);
        }
        addLiquidityToBalancerVault(maturity, 100000 * 10**tDecimals);
        uint256 ytBalBefore = ERC20(yt).balanceOf(alice);
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 ptBal = tBal.fdiv(balancerVault.EXCHANGE_RATE());
        vm.expectEmit(true, false, false, false);
        emit Swapped(address(this), "0", adapter.target(), address(0), 0, 0, msg.sig);
        periphery.swapUnderlyingForPTs(address(adapter), maturity, uBal, 0);
        assertEq(ytBalBefore, ERC20(yt).balanceOf(alice));
        assertApproxEqAbs(ptBalBefore + ptBal, ERC20(pt).balanceOf(alice), 1);
    }
    function testSwapPTsForTarget() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, ) = periphery.sponsorSeries(address(adapter), maturity, true);
        addLiquidityToBalancerVault(maturity, 1000e18);
        divider.issue(address(adapter), maturity, tBal);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(alice);
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 rate = balancerVault.EXCHANGE_RATE();
        uint256 swapped = ptBalBefore.fmul(rate);
        ERC20(pt).approve(address(periphery), ptBalBefore);
        vm.expectEmit(true, false, false, false);
        emit Swapped(address(this), "0", adapter.target(), address(0), 0, 0, msg.sig);
        periphery.swapPTsForTarget(address(adapter), maturity, ptBalBefore, 0);
        assertEq(tBalBefore + swapped, target.balanceOf(alice));
    }
    function testSwapPTsForUnderlying() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, ) = periphery.sponsorSeries(address(adapter), maturity, true);
        addLiquidityToBalancerVault(maturity, 1000e18);
        divider.issue(address(adapter), maturity, tBal);
        uint256 uBalBefore = ERC20(adapter.underlying()).balanceOf(alice);
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 rate = balancerVault.EXCHANGE_RATE();
        uint256 swapped = ptBalBefore.fmul(rate);
        uint256 scale = adapter.scale();
        uint256 uBal = uDecimals > tDecimals
            ? swapped.fmul(scale) * SCALING_FACTOR
            : swapped.fmul(scale) / SCALING_FACTOR;
        ERC20(pt).approve(address(periphery), ptBalBefore);
        vm.expectEmit(true, false, false, false);
        emit Swapped(address(this), "0", adapter.target(), address(0), 0, 0, msg.sig);
        periphery.swapPTsForUnderlying(address(adapter), maturity, ptBalBefore, 0);
        assertEq(uBalBefore + uBal, ERC20(underlying).balanceOf(alice));
    }
    function testSwapYTsForTarget() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 targetToBorrow = 9025 * 10**(tDecimals - 2);
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lscale = adapter.scale();
        addLiquidityToBalancerVault(maturity, 1000 * 10**tDecimals);
        vm.prank(bob);
        divider.issue(address(adapter), maturity, tBal);
        uint256 tBalBefore = target.balanceOf(bob);
        uint256 ytBalBefore = ERC20(yt).balanceOf(bob);
        uint256 zSwapped = targetToBorrow.fdiv(balancerVault.EXCHANGE_RATE());
        uint256 tCombined = zSwapped.fdiv(lscale);
        uint256 remainingYTInTarget = tCombined - targetToBorrow;
        vm.prank(bob);
        ERC20(yt).approve(address(periphery), ytBalBefore);
        vm.prank(bob);
        periphery.swapYTsForTarget(address(adapter), maturity, ytBalBefore);
        assertEq(tBalBefore + remainingYTInTarget, target.balanceOf(bob));
    }
    function testAddLiquidityFirstTimeWithSellYieldModeShouldNotIssue() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        vm.prank(bob);
        (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromTarget(
            address(adapter),
            maturity,
            tBal,
            0,
            type(uint256).max
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(bob);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        assertEq(targetBal, 0);
        assertEq(ytBal, 0);
        assertEq(lpShares, lpBalAfter - lpBalBefore);
        assertEq(tBalBefore - tBal, tBalAfter);
        assertEq(lpBalBefore + 100e18, lpBalAfter);
    }
    function testAddLiquidityFirstTimeWithHoldYieldModeShouldNotIssue() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        vm.prank(bob);
        (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromTarget(
            address(adapter),
            maturity,
            tBal,
            1,
            type(uint256).max
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(bob);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        assertEq(targetBal, 0);
        assertEq(ytBal, 0);
        assertEq(lpShares, lpBalAfter - lpBalBefore);
        assertEq(tBalBefore - tBal, tBalAfter);
        assertEq(lpBalBefore + 100e18, lpBalAfter);
    }
    function testAddLiquidityAndSellYieldWith0_TargetRatioShouldNotIssue() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        periphery.addLiquidityFromTarget(address(adapter), maturity, 1, 0, type(uint256).max);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        vm.prank(bob);
        (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromTarget(
            address(adapter),
            maturity,
            tBal,
            0,
            type(uint256).max
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(bob);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        assertEq(targetBal, 0);
        assertEq(ytBal, 0);
        assertEq(lpShares, lpBalAfter - lpBalBefore);
        assertEq(tBalBefore - tBal, tBalAfter);
        assertEq(lpBalBefore + 100e18, lpBalAfter);
    }
    function testAddLiquidityAndHoldYieldWith0_TargetRatioShouldNotIssue() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        periphery.addLiquidityFromTarget(address(adapter), maturity, 1, 0, type(uint256).max);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        vm.prank(bob);
        (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromTarget(
            address(adapter),
            maturity,
            tBal,
            1,
            type(uint256).max
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(bob);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        assertEq(targetBal, 0);
        assertEq(ytBal, 0);
        assertEq(lpShares, lpBalAfter - lpBalBefore);
        assertEq(tBalBefore - tBal, tBalAfter);
        assertEq(lpBalBefore + 100e18, lpBalAfter);
    }
    function testAddLiquidityAndSellYT() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, ) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lscale = adapter.scale();
        addLiquidityToBalancerVault(maturity, 1000e18);
        periphery.addLiquidityFromTarget(address(adapter), maturity, 1, 0, type(uint256).max);
        uint256 targetToBorrow;
        {
            uint256 tBase = 10**tDecimals;
            uint256 ptiBal = ERC20(pt).balanceOf(address(balancerVault));
            uint256 targetiBal = target.balanceOf(address(balancerVault));
            uint256 computedTarget = tBal.fmul(
                ptiBal.fdiv(adapter.scale().fmul(targetiBal).fmul(FixedMath.WAD - adapter.ifee()) + ptiBal, tBase),
                tBase
            ); 
            uint256 fee = computedTarget.fmul(adapter.ifee());
            uint256 toBeIssued = (computedTarget - fee).fmul(lscale);
            MockSpacePool pool = MockSpacePool(spaceFactory.pools(address(adapter), maturity));
            targetToBorrow = pool.onSwap(
                BalancerPool.SwapRequest({
                    kind: BalancerVault.SwapKind.GIVEN_OUT,
                    tokenIn: ERC20(address(target)),
                    tokenOut: ERC20(pt),
                    amount: toBeIssued,
                    poolId: 0,
                    lastChangeBlock: 0,
                    from: address(0),
                    to: address(0),
                    userData: ""
                }),
                0,
                0
            );
        }
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        uint256 remainingYTInTarget;
        {
            uint256 zSwapped = targetToBorrow.fdiv(balancerVault.EXCHANGE_RATE());
            uint256 tCombined = zSwapped.fdiv(lscale);
            remainingYTInTarget = tCombined - targetToBorrow;
        }
        vm.prank(bob);
        (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromTarget(
            address(adapter),
            maturity,
            tBal,
            0,
            type(uint256).max
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(bob);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        assertTrue(targetBal > 0);
        assertTrue(ytBal > 0);
        assertEq(lpShares, lpBalAfter - lpBalBefore);
        assertApproxEqAbs(tBalBefore - tBal + remainingYTInTarget, tBalAfter, 10);
        assertEq(lpBalBefore + 100e18, lpBalAfter);
    }
    function testAddLiquidityAndHoldYT() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        addLiquidityToBalancerVault(maturity, 1000 * 10**tDecimals);
        periphery.addLiquidityFromTarget(address(adapter), maturity, 1, 1, type(uint256).max);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        uint256 ytBalBefore = ERC20(yt).balanceOf(bob);
        uint256 toBeIssued;
        {
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(0);
            uint256 scale = adapter.scale();
            uint256 proportionalTarget = tBal.fmul(
                balances[1].fdiv(
                    scale.fmul(balances[0]).fmul(FixedMath.WAD - adapter.ifee()) + balances[1],
                    10**tDecimals
                ),
                10**tDecimals
            ); 
            uint256 fee = proportionalTarget.fmul(adapter.ifee());
            toBeIssued = (proportionalTarget - fee).fmul(scale);
        }
        {
            vm.prank(bob);
            (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromTarget(
                address(adapter),
                maturity,
                tBal,
                1,
                type(uint256).max
            );
            assertEq(targetBal, 0);
            assertTrue(ytBal > 0);
            assertEq(lpShares, ERC20(balancerVault.yieldSpacePool()).balanceOf(bob) - lpBalBefore);
            assertEq(tBalBefore - tBal, ERC20(adapter.target()).balanceOf(bob));
            assertEq(lpBalBefore + 100e18, ERC20(balancerVault.yieldSpacePool()).balanceOf(bob));
            assertEq(ytBalBefore + toBeIssued, ERC20(yt).balanceOf(bob));
        }
    }
    function testAddLiquidityFromUnderlyingAndHoldYT() public {
        uint256 uBal = 100 * 10**uDecimals; 
        uint256 maturity = getValidMaturity(2021, 10);
        (, address yt) = periphery.sponsorSeries(address(adapter), maturity, true);
        addLiquidityToBalancerVault(maturity, 1000 * 10**tDecimals);
        periphery.addLiquidityFromTarget(address(adapter), maturity, 1, 1, type(uint256).max);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        uint256 uBalBefore = ERC20(adapter.underlying()).balanceOf(bob);
        uint256 ytBalBefore = ERC20(yt).balanceOf(bob);
        uint256 toBeIssued;
        {
            uint256 lscale = adapter.scale();
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(0);
            uint256 tBal;
            if (!is4626Target) {
                tBal = uDecimals > tDecimals
                    ? uBal.fdivUp(lscale) / SCALING_FACTOR
                    : uBal.fdivUp(lscale) * SCALING_FACTOR;
            } else {
                tBal = target.previewDeposit(uBal);
            }
            uint256 proportionalTarget = tBal.fmul(
                balances[1].fdiv(lscale.fmul(FixedMath.WAD - adapter.ifee()).fmul(balances[0]) + balances[1])
            ); 
            uint256 fee = uint256(adapter.ifee()).fmul(proportionalTarget);
            toBeIssued = (proportionalTarget - fee).fmul(lscale);
        }
        {
            vm.prank(bob);
            (uint256 targetBal, uint256 ytBal, uint256 lpShares) = periphery.addLiquidityFromUnderlying(
                address(adapter),
                maturity,
                uBal,
                1,
                type(uint256).max
            );
            assertEq(targetBal, 0);
            assertTrue(ytBal > 0);
            assertEq(lpShares, ERC20(balancerVault.yieldSpacePool()).balanceOf(bob) - lpBalBefore);
            assertEq(uBalBefore - uBal, ERC20(adapter.underlying()).balanceOf(bob));
            assertEq(lpBalBefore + 100e18, ERC20(balancerVault.yieldSpacePool()).balanceOf(bob));
            assertEq(toBeIssued, ytBal);
            assertEq(ytBalBefore + toBeIssued, ERC20(yt).balanceOf(bob));
        }
    }
    function testRemoveLiquidityBeforeMaturity() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lscale = adapter.scale();
        uint256[] memory minAmountsOut = new uint256[](2);
        addLiquidityToBalancerVault(maturity, 1000e18);
        {
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(0);
            uint256 proportionalTarget = tBal *
                (balances[1] / ((1e18 * balances[0] * (FixedMath.WAD - adapter.ifee())) / FixedMath.WAD + balances[1])); 
            uint256 fee = convertToBase(adapter.ifee(), tDecimals).fmul(proportionalTarget, 10**tDecimals);
            uint256 toBeIssued = (proportionalTarget - fee).fmul(lscale);
            minAmountsOut[0] = (tBal - proportionalTarget).fmul(lscale); 
            minAmountsOut[1] = toBeIssued; 
        }
        vm.startPrank(bob);
        periphery.addLiquidityFromTarget(address(adapter), maturity, tBal, 1, type(uint256).max);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(bob);
        {
            uint256 uBal = minAmountsOut[1].fmul(balancerVault.EXCHANGE_RATE()); 
            tBal = (minAmountsOut[0] + uBal).fdiv(lscale); 
        }
        uint256 lpBal = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        balancerVault.yieldSpacePool().approve(address(periphery), lpBal);
        (uint256 targetBal, uint256 ptBal) = periphery.removeLiquidity(
            address(adapter),
            maturity,
            lpBal,
            minAmountsOut,
            0,
            true
        );
        vm.stopPrank();
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(bob);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(bob);
        assertEq(targetBal, tBalAfter - tBalBefore);
        assertEq(tBalBefore + tBal, tBalAfter);
        assertEq(lpBalAfter, 0);
        assertEq(ptBal, 0);
    }
    function testRemoveLiquidityOnMaturity() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, ) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lscale = adapter.scale();
        uint256[] memory minAmountsOut = new uint256[](2);
        addLiquidityToBalancerVault(maturity, 1000e18);
        {
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(0);
            uint256 proportionalTarget = tBal * (balances[1] / (1e18 * balances[0] + balances[1])); 
            uint256 fee = convertToBase(adapter.ifee(), tDecimals).fmul(proportionalTarget, 10**tDecimals);
            uint256 toBeIssued = (proportionalTarget - fee).fmul(lscale);
            minAmountsOut[0] = (tBal - proportionalTarget).fmul(lscale); 
            minAmountsOut[1] = toBeIssued; 
        }
        periphery.addLiquidityFromTarget(address(adapter), maturity, tBal, 1, type(uint256).max);
        vm.warp(maturity);
        divider.settleSeries(address(adapter), maturity);
        lscale = adapter.scale();
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(alice);
        uint256 lpBal = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        balancerVault.yieldSpacePool().approve(address(periphery), lpBal);
        (uint256 targetBal, ) = periphery.removeLiquidity(address(adapter), maturity, lpBal, minAmountsOut, 0, true);
        uint256 ptBalAfter = ERC20(pt).balanceOf(alice);
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(alice);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        assertEq(ptBalBefore, ptBalAfter);
        assertEq(targetBal, tBalAfter - tBalBefore);
        assertApproxEqAbs(tBalBefore + tBal, tBalAfter);
        assertEq(lpBalAfter, 0);
    }
    function testRemoveLiquidityOnMaturityAndPTRedeemRestricted() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        MockToken underlying = new MockToken("Usdc Token", "USDC", uDecimals);
        MockTargetLike target = MockTargetLike(
            deployMockTarget(address(underlying), "Compound USDC", "cUSDC", tDecimals)
        );
        divider.setPermissionless(true);
        uint16 level = 0x1 + 0x2 + 0x4 + 0x8; 
        DEFAULT_ADAPTER_PARAMS.level = level;
        MockAdapter aAdapter = MockAdapter(deployMockAdapter(address(divider), address(target), address(reward)));
        periphery.verifyAdapter(address(aAdapter), true);
        periphery.onboardAdapter(address(aAdapter), true);
        divider.setGuard(address(aAdapter), 10 * 2**128);
        target.approve(address(divider), type(uint256).max);
        underlying.approve(address(target), type(uint256).max);
        vm.startPrank(bob);
        target.approve(address(periphery), type(uint256).max);
        underlying.approve(address(target), type(uint256).max);
        vm.stopPrank();
        if (!is4626Target) {
            target.mint(alice, 10000000 * 10**tDecimals);
            vm.prank(bob);
            target.mint(bob, 10000000 * 10**tDecimals);
        } else {
            underlying.mint(alice, 10000000 * 10**uDecimals);
            underlying.mint(bob, 10000000 * 10**uDecimals);
            target.deposit(10000000 * 10**uDecimals, alice);
            vm.prank(bob);
            target.deposit(10000000 * 10**uDecimals, bob);
        }
        (address pt, ) = periphery.sponsorSeries(address(aAdapter), maturity, true);
        spaceFactory.create(address(aAdapter), maturity);
        uint256 lscale = aAdapter.scale();
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = 2 * 10**tDecimals;
        minAmountsOut[1] = 1 * 10**tDecimals;
        addLiquidityToBalancerVault(address(aAdapter), maturity, 1000 * 10**tDecimals);
        vm.prank(bob);
        periphery.addLiquidityFromTarget(address(aAdapter), maturity, tBal, 1, type(uint256).max);
        vm.warp(maturity);
        divider.settleSeries(address(aAdapter), maturity);
        lscale = aAdapter.scale();
        uint256 ptBalBefore = ERC20(pt).balanceOf(bob);
        uint256 tBalBefore = ERC20(aAdapter.target()).balanceOf(bob);
        vm.startPrank(bob);
        balancerVault.yieldSpacePool().approve(address(periphery), 3e18);
        (uint256 targetBal, uint256 ptBal) = periphery.removeLiquidity(
            address(aAdapter),
            maturity,
            3 * 10**tDecimals,
            minAmountsOut,
            0,
            true
        );
        vm.stopPrank();
        assertEq(targetBal, ERC20(aAdapter.target()).balanceOf(bob) - tBalBefore);
        assertEq(ptBalBefore, ERC20(pt).balanceOf(bob) - minAmountsOut[1]);
        assertEq(ptBal, ERC20(pt).balanceOf(bob) - ptBalBefore);
        assertEq(ptBal, 10**tDecimals);
    }
    function testRemoveLiquidityWhenOneSideLiquidity() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, ) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256[] memory minAmountsOut = new uint256[](2);
        periphery.addLiquidityFromTarget(address(adapter), maturity, tBal, 1, type(uint256).max);
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(alice);
        uint256 lpBalBefore = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        balancerVault.yieldSpacePool().approve(address(periphery), lpBalBefore);
        (uint256 targetBal, uint256 ptBal) = periphery.removeLiquidity(
            address(adapter),
            maturity,
            lpBalBefore,
            minAmountsOut,
            0,
            true
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(alice);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        uint256 ptBalAfter = ERC20(pt).balanceOf(alice);
        assertTrue(tBalAfter > 0);
        assertEq(targetBal, tBalAfter - tBalBefore);
        assertEq(ptBalAfter, ptBalBefore);
        assertEq(lpBalAfter, 0);
        assertEq(ptBal, 0);
        assertTrue(lpBalBefore > 0);
    }
    function testRemoveLiquidityAndSkipSwap() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        (address pt, ) = periphery.sponsorSeries(address(adapter), maturity, true);
        uint256 lscale = adapter.scale();
        uint256[] memory minAmountsOut = new uint256[](2);
        addLiquidityToBalancerVault(maturity, 1000 * 10**tDecimals);
        uint256 ptToBeIssued;
        {
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(0);
            uint256 fee = adapter.ifee();
            uint256 tBase = 10**tDecimals;
            uint256 proportionalTarget = tBal.fmul(
                balances[1].fdiv(lscale.fmul(FixedMath.WAD - fee).fmul(balances[0]) + balances[1], tBase),
                tBase
            );
            ptToBeIssued = proportionalTarget.fmul(lscale);
            minAmountsOut[0] = (tBal - proportionalTarget).fmul(lscale); 
            minAmountsOut[1] = ptToBeIssued; 
        }
        periphery.addLiquidityFromTarget(address(adapter), maturity, tBal, 1, type(uint256).max);
        uint256 tBalBefore = ERC20(adapter.target()).balanceOf(alice);
        uint256 ptBalBefore = ERC20(pt).balanceOf(alice);
        uint256 lpBal = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        balancerVault.yieldSpacePool().approve(address(periphery), lpBal);
        (uint256 targetBal, uint256 ptBal) = periphery.removeLiquidity(
            address(adapter),
            maturity,
            lpBal,
            minAmountsOut,
            0,
            false
        );
        uint256 tBalAfter = ERC20(adapter.target()).balanceOf(alice);
        uint256 lpBalAfter = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        uint256 ptBalAfter = ERC20(pt).balanceOf(alice);
        assertEq(tBalAfter, tBalBefore + targetBal);
        assertEq(lpBalAfter, 0);
        assertEq(ptBal, ptToBeIssued);
        assertEq(ptBalAfter, ptBalBefore + ptToBeIssued);
    }
    function testRemoveLiquidityAndUnwrapTarget() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        vm.warp(block.timestamp + 5 days);
        uint256 lscale = adapter.scale();
        uint256[] memory minAmountsOut = new uint256[](2);
        addLiquidityToBalancerVault(maturity, 1000e18);
        uint256 ptToBeIssued;
        uint256 targetToBeAdded;
        {
            (, uint256[] memory balances, ) = balancerVault.getPoolTokens(0);
            uint256 fee = adapter.ifee();
            uint256 tBase = 10**tDecimals;
            uint256 proportionalTarget = tBal.fmul(
                balances[1].fdiv(lscale.fmul(FixedMath.WAD - fee).fmul(balances[0]) + balances[1], tBase),
                tBase
            );
            ptToBeIssued = proportionalTarget.fmul(lscale);
            targetToBeAdded = (tBal - proportionalTarget); 
            minAmountsOut[0] = targetToBeAdded;
            minAmountsOut[1] = ptToBeIssued; 
        }
        periphery.addLiquidityFromTarget(address(adapter), maturity, tBal, 1, type(uint256).max);
        uint256 uBalBefore = ERC20(adapter.underlying()).balanceOf(alice);
        uint256 lpBal = ERC20(balancerVault.yieldSpacePool()).balanceOf(alice);
        balancerVault.yieldSpacePool().approve(address(periphery), lpBal);
        (uint256 underlyingBal, uint256 ptBal) = periphery.removeLiquidityAndUnwrapTarget(
            address(adapter),
            maturity,
            lpBal,
            minAmountsOut,
            0,
            false
        );
        uint256 uBalAfter = ERC20(adapter.underlying()).balanceOf(alice);
        assertEq(ERC20(balancerVault.yieldSpacePool()).balanceOf(alice), 0);
        assertEq(ptBal, ptToBeIssued);
        assertEq(uBalBefore + underlyingBal, uBalAfter);
        assertEq(
            underlyingBal,
            uDecimals > tDecimals
                ? targetToBeAdded.fmul(lscale) * SCALING_FACTOR
                : targetToBeAdded.fmul(lscale) / SCALING_FACTOR
        );
    }
    function testCantMigrateLiquidityIfTargetsAreDifferent() public {
        uint256 tBal = 100 * 10**tDecimals;
        uint256 maturity = getValidMaturity(2021, 10);
        periphery.sponsorSeries(address(adapter), maturity, true);
        addLiquidityToBalancerVault(maturity, 1000e18);
        MockTargetLike otherTarget = MockTargetLike(deployMockTarget(address(underlying), "Compound Usdc", "cUSDC", 8));
        factory.supportTarget(address(otherTarget), true);
        address[] memory rewardTokens;
        address dstAdapter = periphery.deployAdapter(address(factory), address(otherTarget), abi.encode(rewardTokens)); 
        (, , uint256 lpShares) = periphery.addLiquidityFromTarget(
            address(adapter),
            maturity,
            tBal,
            0,
            type(uint256).max
        );
        uint256[] memory minAmountsOut = new uint256[](2);
        vm.expectRevert(abi.encodeWithSelector(Errors.TargetMismatch.selector));
        periphery.migrateLiquidity(
            address(adapter),
            dstAdapter,
            maturity,
            maturity,
            lpShares,
            minAmountsOut,
            0,
            0,
            true,
            type(uint256).max
        );
    }
    function testMigrateLiquidity() public {
    }
    function testQuotePrice() public {
    }
    event FactoryChanged(address indexed factory, bool indexed isOn);
    event SpaceFactoryChanged(address oldSpaceFactory, address newSpaceFactory);
    event PoolManagerChanged(address oldPoolManager, address newPoolManager);
    event SeriesSponsored(address indexed adapter, uint256 indexed maturity, address indexed sponsor);
    event AdapterDeployed(address indexed adapter);
    event AdapterOnboarded(address indexed adapter);
    event AdapterVerified(address indexed adapter);
    event Swapped(
        address indexed sender,
        bytes32 indexed poolId,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes4 indexed sig
    );
    event TargetAdded(address indexed target, address indexed cTarget);
    event SeriesQueued(address indexed adapter, uint256 indexed maturity, address indexed pool);
}