pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { FixedMath } from "../external/FixedMath.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Periphery } from "../Periphery.sol";
import { PoolManager } from "@sense-finance/v1-fuse/src/PoolManager.sol";
import { Divider } from "../Divider.sol";
import { BaseFactory } from "../adapters/abstract/factories/BaseFactory.sol";
import { BaseAdapter } from "../adapters/abstract/BaseAdapter.sol";
import { CAdapter } from "../adapters/implementations/compound/CAdapter.sol";
import { FAdapter } from "../adapters/implementations/fuse/FAdapter.sol";
import { CFactory } from "../adapters/implementations/compound/CFactory.sol";
import { FFactory } from "../adapters/implementations/fuse/FFactory.sol";
import { DateTimeFull } from "./test-helpers/DateTimeFull.sol";
import { MockOracle } from "./test-helpers/mocks/fuse/MockOracle.sol";
import { MockAdapter, MockCropAdapter } from "./test-helpers/mocks/MockAdapter.sol";
import { MockTarget } from "./test-helpers/mocks/MockTarget.sol";
import { MockToken } from "./test-helpers/mocks/MockToken.sol";
import { Constants } from "./test-helpers/Constants.sol";
import { AddressBook } from "./test-helpers/AddressBook.sol";
import { BalancerVault } from "../external/balancer/Vault.sol";
import { BalancerPool } from "../external/balancer/Pool.sol";
interface SpaceFactoryLike {
    function create(address, uint256) external returns (address);
    function pools(address adapter, uint256 maturity) external view returns (address);
    function setParams(
        uint256 _ts,
        uint256 _g1,
        uint256 _g2,
        bool _oracleEnabled
    ) external;
}
contract PeripheryTestHelper is Test {
    uint256 public origin;
    Periphery internal periphery;
    CFactory internal cfactory;
    FFactory internal ffactory;
    MockOracle internal mockOracle;
    MockTarget internal mockTarget;
    MockCropAdapter internal mockAdapter;
    address internal balancerVault;
    address internal spaceFactory;
    address internal poolManager;
    address internal divider;
    uint128 internal constant IFEE_FOR_YT_SWAPS = 0.042e18; 
    function setUp() public {
        origin = block.timestamp;
        (uint256 year, uint256 month, ) = DateTimeFull.timestampToDate(block.timestamp);
        uint256 firstDayOfMonth = DateTimeFull.timestampFromDateTime(year, month, 1, 0, 0, 0);
        vm.warp(firstDayOfMonth); 
        MockToken underlying = new MockToken("TestUnderlying", "TU", 18);
        mockTarget = new MockTarget(address(underlying), "TestTarget", "TT", 18);
        divider = AddressBook.DIVIDER_1_2_0;
        spaceFactory = AddressBook.SPACE_FACTORY_1_2_0;
        balancerVault = AddressBook.BALANCER_VAULT;
        poolManager = AddressBook.POOL_MANAGER_1_2_0;
        mockOracle = new MockOracle();
        BaseAdapter.AdapterParams memory mockAdapterParams = BaseAdapter.AdapterParams({
            oracle: address(mockOracle),
            stake: address(new MockToken("Stake", "ST", 18)), 
            stakeSize: 0,
            minm: 0, 
            maxm: type(uint64).max, 
            mode: 0, 
            tilt: 0,
            level: Constants.DEFAULT_LEVEL
        });
        mockAdapter = new MockCropAdapter(
            address(divider),
            address(mockTarget),
            mockTarget.underlying(),
            Constants.REWARDS_RECIPIENT,
            IFEE_FOR_YT_SWAPS,
            mockAdapterParams,
            address(new MockToken("Reward", "R", 18))
        );
        vm.label(spaceFactory, "SpaceFactory");
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: AddressBook.DAI,
            oracle: address(mockOracle),
            ifee: Constants.DEFAULT_ISSUANCE_FEE,
            stakeSize: Constants.DEFAULT_STAKE_SIZE,
            minm: Constants.DEFAULT_MIN_MATURITY,
            maxm: Constants.DEFAULT_MAX_MATURITY,
            mode: Constants.DEFAULT_MODE,
            tilt: Constants.DEFAULT_TILT,
            guard: Constants.DEFAULT_GUARD
        });
        cfactory = new CFactory(
            divider,
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT,
            factoryParams,
            AddressBook.COMP
        );
        ffactory = new FFactory(divider, Constants.RESTRICTED_ADMIN, Constants.REWARDS_RECIPIENT, factoryParams);
        periphery = new Periphery(divider, poolManager, spaceFactory, balancerVault);
        periphery.setFactory(address(cfactory), true);
        periphery.setFactory(address(ffactory), true);
        vm.startPrank(AddressBook.SENSE_ADMIN_MULTISIG);
        Divider(divider).setIsTrusted(address(cfactory), true);
        Divider(divider).setIsTrusted(address(ffactory), true);
        Divider(divider).setPeriphery(address(periphery));
        Divider(divider).setGuard(address(mockAdapter), type(uint256).max);
        PoolManager(poolManager).setIsTrusted(address(periphery), true);
        uint256 ts = 1e18 / (uint256(31536000) * uint256(12));
        uint256 g1 = (uint256(950) * 1e18) / uint256(1000);
        uint256 g2 = (uint256(1000) * 1e18) / uint256(950);
        SpaceFactoryLike(spaceFactory).setParams(ts, g1, g2, true);
        vm.stopPrank(); 
        periphery.onboardAdapter(address(mockAdapter), true);
        periphery.verifyAdapter(address(mockAdapter), true);
        mockAdapter.setScale(1e18);
        mockTarget.approve(address(periphery), type(uint256).max);
    }
}
contract PeripheryMainnetTests is PeripheryTestHelper {
    using FixedMath for uint256;
    function testMainnetSponsorSeriesOnCAdapter() public {
        vm.warp(origin);
        address f = periphery.deployAdapter(address(cfactory), AddressBook.cBAT, "");
        CAdapter cadapter = CAdapter(payable(f));
        deal(AddressBook.DAI, address(this), type(uint256).max);
        (uint256 year, uint256 month, ) = DateTimeFull.timestampToDate(
            block.timestamp + Constants.DEFAULT_MIN_MATURITY
        );
        uint256 maturity = DateTimeFull.timestampFromDateTime(
            month == 12 ? year + 1 : year,
            month == 12 ? 1 : (month + 1),
            1,
            0,
            0,
            0
        );
        ERC20(AddressBook.DAI).approve(address(periphery), type(uint256).max);
        (address pt, address yt) = periphery.sponsorSeries(address(cadapter), maturity, false);
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        (PoolManager.SeriesStatus status, ) = PoolManager(poolManager).sSeries(address(cadapter), maturity);
        assertTrue(status == PoolManager.SeriesStatus.QUEUED);
    }
    function testMainnetSponsorSeriesOnFAdapter() public {
        vm.warp(origin);
        address f = periphery.deployAdapter(
            address(ffactory),
            AddressBook.f156FRAX3CRV,
            abi.encode(AddressBook.TRIBE_CONVEX)
        );
        FAdapter fadapter = FAdapter(payable(f));
        deal(AddressBook.DAI, address(this), type(uint256).max);
        (uint256 year, uint256 month, ) = DateTimeFull.timestampToDate(
            block.timestamp + Constants.DEFAULT_MIN_MATURITY
        );
        uint256 maturity = DateTimeFull.timestampFromDateTime(
            month == 12 ? year + 1 : year,
            month == 12 ? 1 : (month + 1),
            1,
            0,
            0,
            0
        );
        ERC20(AddressBook.DAI).approve(address(periphery), type(uint256).max);
        (address pt, address yt) = periphery.sponsorSeries(address(fadapter), maturity, false);
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        (PoolManager.SeriesStatus status, ) = PoolManager(poolManager).sSeries(address(fadapter), maturity);
        assertTrue(status == PoolManager.SeriesStatus.QUEUED);
    }
    function testMainnetSponsorSeriesOnMockAdapter() public {
        (uint256 maturity, address pt, address yt) = _sponsorSeries();
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        (PoolManager.SeriesStatus status, ) = PoolManager(poolManager).sSeries(address(mockAdapter), maturity);
        assertTrue(status == PoolManager.SeriesStatus.QUEUED);
    }
    function testMainnetSponsorSeriesOnMockAdapterWhenPoolManagerZero() public {
        periphery.setPoolManager(address(0));
        (uint256 maturity, address pt, address yt) = _sponsorSeries();
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
    }
    function testMainnetSwapYTsForTarget() public {
        (uint256 maturity, address pt, address yt) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 ytBalPre = ERC20(yt).balanceOf(address(this));
        uint256 targetBalPre = mockTarget.balanceOf(address(this));
        ERC20(yt).approve(address(periphery), ytBalPre / 10);
        periphery.swapYTsForTarget(address(mockAdapter), maturity, ytBalPre / 10);
        uint256 ytBalPost = ERC20(yt).balanceOf(address(this));
        uint256 targetBalPost = mockTarget.balanceOf(address(this));
        assertLt(ytBalPost, ytBalPre);
        assertGt(targetBalPost, targetBalPre);
    }
    function testMainnetSwapTargetForYTsReturnValues() public {
        (uint256 maturity, address pt, address yt) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.0234e18;
        uint256 TARGET_TO_BORROW = 0.1413769e18;
        uint256 targetBalPre = mockTarget.balanceOf(address(this));
        uint256 ytBalPre = ERC20(yt).balanceOf(address(this));
        (uint256 targetReturned, uint256 ytsOut) = periphery.swapTargetForYTs(
            address(mockAdapter),
            maturity,
            TARGET_IN,
            TARGET_TO_BORROW,
            TARGET_TO_BORROW 
        );
        uint256 targetBalPost = mockTarget.balanceOf(address(this));
        uint256 ytBalPost = ERC20(yt).balanceOf(address(this));
        assertEq(targetBalPre - targetBalPost + targetReturned, TARGET_IN);
        assertEq(ytBalPost - ytBalPre, ytsOut);
        assertEq(ytsOut, (TARGET_IN + TARGET_TO_BORROW).fmul(1e18 - mockAdapter.ifee()));
        assertTrue(targetReturned < 0.000001e18);
    }
    function testMainnetSwapTargetForYTsBorrowCheckOne() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.005e18;
        uint256 TARGET_TO_BORROW = 0.03340541e18;
        _checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
    }
    function testMainnetSwapTargetForYTsBorrowCheckTwo() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.01e18;
        uint256 TARGET_TO_BORROW = 0.06489898e18;
        _checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
    }
    function testMainnetSwapTargetForYTsBorrowCheckThree() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.0234e18;
        uint256 TARGET_TO_BORROW = 0.1413769e18;
        _checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
    }
    function testMainnetSwapTargetForYTsBorrowCheckFour() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.00003e18;
        uint256 TARGET_TO_BORROW = 0.0002066353449e18;
        _checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
    }
    function testMainnetSwapTargetForYTsBorrowTooMuch() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.0234e18;
        uint256 TARGET_TO_BORROW = 0.1413769e18 + 0.02e18;
        vm.expectRevert("TRANSFER_FROM_FAILED");
        this._checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, 0);
    }
    function testMainnetSwapTargetForYTsBorrowTooLittle() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.0234e18;
        uint256 TARGET_TO_BORROW = 0.1413769e18 - 0.02e18;
        vm.expectRevert("TOO_MANY_TARGET_RETURNED");
        this._checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, 0);
    }
    function testMainnetSwapTargetForYTsMinOut() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.0234e18;
        uint256 TARGET_TO_BORROW = 0.1413769e18;
        vm.expectRevert("BAL#507"); 
        this._checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW / 2, TARGET_TO_BORROW); 
        vm.expectRevert("BAL#507"); 
        this._checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW.fmul(1.01e18));
        (uint256 targetReturnedPreview, ) = _callStaticBuyYTs(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
        assertGt(targetReturnedPreview, 0);
        vm.expectRevert("BAL#507"); 
        this._checkYTBuyingParameters(
            maturity,
            TARGET_IN,
            TARGET_TO_BORROW,
            TARGET_TO_BORROW + targetReturnedPreview + 1
        );
        this._checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW + targetReturnedPreview);
    }
    function testMainnetSwapTargetForYTsTransferOutOfBounds() public {
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), 1e18, 0.5e18);
        uint256 TARGET_IN = 0.0234e18;
        uint256 TARGET_TO_BORROW = 0.1413769e18;
        uint256 TARGET_TRANSFERRED_IN = 0.5e18;
        (uint256 targetReturnedPreview, ) = _callStaticBuyYTs(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
        mockTarget.mint(address(periphery), TARGET_TRANSFERRED_IN);
        (uint256 targetReturned, uint256 ytsOut) = periphery.swapTargetForYTs(
            address(mockAdapter),
            maturity,
            TARGET_IN,
            TARGET_TO_BORROW,
            TARGET_TO_BORROW
        );
        assertEq(targetReturnedPreview + TARGET_TRANSFERRED_IN, targetReturned);
        assertEq(ytsOut, (TARGET_IN + TARGET_TO_BORROW).fmul(1e18 - mockAdapter.ifee()));
    }
    function testMainnetFuzzSwapTargetForYTsDifferentDecimals(uint8 underlyingDecimals, uint8 targetDecimals) public {
        underlyingDecimals = _fuzzWithBounds(underlyingDecimals, 4, 19);
        targetDecimals = _fuzzWithBounds(targetDecimals, 4, 19);
        MockToken newUnderlying = new MockToken("TestUnderlying", "TU", underlyingDecimals);
        MockTarget newMockTarget = new MockTarget(address(newUnderlying), "TestTarget", "TT", targetDecimals);
        vm.etch(mockTarget.underlying(), address(newUnderlying).code);
        vm.etch(address(mockTarget), address(newMockTarget).code);
        (uint256 maturity, address pt, ) = _sponsorSeries();
        assertEq(uint256(ERC20(pt).decimals()), uint256(targetDecimals));
        _initializePool(maturity, ERC20(pt), 10**targetDecimals, 10**targetDecimals / 2);
        uint256 TARGET_IN = uint256(0.0234e18).fmul(10**targetDecimals);
        uint256 TARGET_TO_BORROW = uint256(0.1413769e18).fmul(10**targetDecimals);
        _checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, TARGET_TO_BORROW);
    }
    function testMainnetFuzzSwapTargetForYTsDifferentScales(uint64 initScale, uint64 scale) public {
        vm.assume(initScale >= 1e9);
        vm.assume(scale >= initScale);
        mockAdapter.setScale(initScale);
        (uint256 maturity, address pt, ) = _sponsorSeries();
        _initializePool(maturity, ERC20(pt), uint256(1e18).fdivUp(initScale), 0.5e18);
        mockAdapter.setScale(scale);
        uint256 TARGET_IN = uint256(0.0234e18).fdivUp(scale);
        uint256 TARGET_TO_BORROW = uint256(0.1413769e18).fdivUp(scale);
        _checkYTBuyingParameters(maturity, TARGET_IN, TARGET_TO_BORROW, 0);
    }
    function _sponsorSeries()
        public
        returns (
            uint256 maturity,
            address pt,
            address yt
        )
    {
        (uint256 year, uint256 month, ) = DateTimeFull.timestampToDate(block.timestamp);
        maturity = DateTimeFull.timestampFromDateTime(year + 1, month, 1, 0, 0, 0);
        (pt, yt) = periphery.sponsorSeries(address(mockAdapter), maturity, false);
    }
    function _initializePool(
        uint256 maturity,
        ERC20 pt,
        uint256 targetToJoin,
        uint256 ptsToSwapIn
    ) public {
        uint256 targetToIssueWith = ptsToSwapIn.fdivUp(1e18 - mockAdapter.ifee()).fdivUp(mockAdapter.scale());
        mockTarget.mint(address(this), targetToIssueWith + targetToJoin);
        mockTarget.approve(address(divider), targetToIssueWith);
        Divider(divider).issue(address(mockAdapter), maturity, targetToIssueWith);
        assertTrue(pt.balanceOf(address(this)) >= ptsToSwapIn && pt.balanceOf(address(this)) <= ptsToSwapIn + 100);
        periphery.addLiquidityFromTarget(address(mockAdapter), maturity, targetToJoin, 1, 0);
        pt.approve(address(periphery), ptsToSwapIn);
        periphery.swapPTsForTarget(address(mockAdapter), maturity, ptsToSwapIn, 0);
    }
    function _checkYTBuyingParameters(
        uint256 maturity,
        uint256 targetIn,
        uint256 targetToBorrow,
        uint256 minOut
    ) public {
        (uint256 targetReturned, uint256 ytsOut) = periphery.swapTargetForYTs(
            address(mockAdapter),
            maturity,
            targetIn,
            targetToBorrow,
            minOut
        );
        require(targetReturned <= targetIn.fmul(0.0001e18), "TOO_MANY_TARGET_RETURNED");
    }
    function _callStaticBuyYTs(
        uint256 maturity,
        uint256 targetIn,
        uint256 targetToBorrow,
        uint256 minOut
    ) public returns (uint256 targetReturnedPreview, uint256 ytsOutPreview) {
        try this._callRevertBuyYTs(maturity, targetIn, targetToBorrow, minOut) {} catch Error(string memory retData) {
            (targetReturnedPreview, ytsOutPreview) = abi.decode(bytes(retData), (uint256, uint256));
        }
    }
    function _callRevertBuyYTs(
        uint256 maturity,
        uint256 targetIn,
        uint256 targetToBorrow,
        uint256 minOut
    ) public {
        (uint256 targetReturned, uint256 ytsOut) = periphery.swapTargetForYTs(
            address(mockAdapter),
            maturity,
            targetIn,
            targetToBorrow,
            minOut
        );
        revert(string(abi.encode(targetReturned, ytsOut)));
    }
    function _fuzzWithBounds(
        uint8 number,
        uint8 lBound,
        uint8 uBound
    ) public returns (uint8) {
        return lBound + (number % (uBound - lBound));
    }
}