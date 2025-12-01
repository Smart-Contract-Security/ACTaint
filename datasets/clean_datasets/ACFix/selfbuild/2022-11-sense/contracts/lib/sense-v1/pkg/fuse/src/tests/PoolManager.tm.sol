pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { FixedMath } from "@sense-finance/v1-core/src/external/FixedMath.sol";
import { Divider, TokenHandler } from "@sense-finance/v1-core/src/Divider.sol";
import { CAdapter } from "@sense-finance/v1-core/src/adapters/implementations/compound/CAdapter.sol";
import { CToken } from "@sense-finance/v1-fuse/src/external/CToken.sol";
import { Token } from "@sense-finance/v1-core/src/tokens/Token.sol";
import { PoolManager, MasterOracleLike } from "../PoolManager.sol";
import { BaseAdapter } from "@sense-finance/v1-core/src/adapters/abstract/BaseAdapter.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { MockFactory } from "@sense-finance/v1-core/src/tests/test-helpers/mocks/MockFactory.sol";
import { MockOracle } from "@sense-finance/v1-core/src/tests/test-helpers/mocks/fuse/MockOracle.sol";
import { MockTarget } from "@sense-finance/v1-core/src/tests/test-helpers/mocks/MockTarget.sol";
import { MockToken } from "@sense-finance/v1-core/src/tests/test-helpers/mocks/MockToken.sol";
import { MockAdapter } from "@sense-finance/v1-core/src/tests/test-helpers/mocks/MockAdapter.sol";
import { DateTimeFull } from "@sense-finance/v1-core/src/tests/test-helpers/DateTimeFull.sol";
import { AddressBook } from "@sense-finance/v1-core/src/tests/test-helpers/AddressBook.sol";
import { Constants } from "@sense-finance/v1-core/src/tests/test-helpers/Constants.sol";
import { MockBalancerVault, MockSpaceFactory, MockSpacePool } from "@sense-finance/v1-core/src/tests/test-helpers/mocks/MockSpace.sol";
import { PriceOracle } from "../external/PriceOracle.sol";
interface ComptrollerLike {
    function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);
    function cTokensByUnderlying(address underlying) external view returns (address);
    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (uint256);
    struct Market {
        bool isListed;
        uint256 collateralFactorMantissa;
    }
    function markets(address cToken) external view returns (Market memory);
}
contract PoolManagerTest is Test {
    using FixedMath for uint256;
    MockToken internal stake;
    MockTarget internal target;
    Divider internal divider;
    TokenHandler internal tokenHandler;
    MockAdapter internal mockAdapter;
    MockOracle internal mockOracle;
    PoolManager internal poolManager;
    MockBalancerVault internal balancerVault;
    MockSpaceFactory internal spaceFactory;
    function setUp() public {
        tokenHandler = new TokenHandler();
        divider = new Divider(address(this), address(tokenHandler));
        tokenHandler.init(address(divider));
        mockOracle = new MockOracle();
        poolManager = new PoolManager(
            AddressBook.POOL_DIR,
            AddressBook.COMPTROLLER_IMPL,
            AddressBook.CERC20_IMPL,
            address(divider),
            AddressBook.MASTER_ORACLE_IMPL
        );
        divider.setPeriphery(address(this));
        MockToken underlying = new MockToken("Underlying Token", "UD", 18);
        stake = new MockToken("Stake", "SBL", 18);
        target = new MockTarget(address(underlying), "Compound Dai", "cDAI", 18);
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: address(mockOracle),
            stake: address(stake),
            stakeSize: 1e18,
            minm: 2 weeks,
            maxm: 14 weeks,
            mode: 0,
            tilt: 0,
            level: 31
        });
        mockAdapter = new MockAdapter(
            address(divider),
            address(target),
            target.underlying(),
            Constants.REWARDS_RECIPIENT,
            0.1e18,
            adapterParams
        );
        mockAdapter.scale();
        divider.setAdapter(address(mockAdapter), true);
        balancerVault = new MockBalancerVault();
        spaceFactory = new MockSpaceFactory(address(balancerVault), address(divider));
    }
    function testMainnetDeployPool() public {
        uint256 maturity = _getValidMaturity();
        _initSeries(maturity);
        assertTrue(poolManager.comptroller() == address(0));
        poolManager.deployPool("Sense Pool", 0.051 ether, 1 ether, AddressBook.MASTER_ORACLE);
        assertTrue(poolManager.comptroller() != address(0));
        vm.expectRevert("ERC1167: create2 failed");
        poolManager.deployPool("Sense Pool", 0.051 ether, 1 ether, AddressBook.MASTER_ORACLE);
    }
    function testMainnetAddTarget() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PoolNotDeployed.selector));
        poolManager.addTarget(address(target), address(mockAdapter));
        poolManager.deployPool("Sense Pool", 0.051 ether, 1 ether, AddressBook.MASTER_ORACLE);
        vm.expectRevert(abi.encodeWithSelector(Errors.TargetParamsNotSet.selector));
        poolManager.addTarget(address(target), address(mockAdapter));
        PoolManager.AssetParams memory params = PoolManager.AssetParams({
            irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
            reserveFactor: 0.1 ether,
            collateralFactor: 0.5 ether
        });
        poolManager.setParams("TARGET_PARAMS", params);
        poolManager.addTarget(address(target), address(mockAdapter));
        vm.expectRevert();
        poolManager.addTarget(address(target), address(mockAdapter));
    }
    function testMainnetQueueSeries() public {
        uint256 maturity = _getValidMaturity();
        vm.expectRevert(abi.encodeWithSelector(Errors.SeriesDoesNotExist.selector));
        poolManager.queueSeries(address(mockAdapter), maturity, address(0));
        _initSeries(maturity);
        vm.expectRevert();
        poolManager.queueSeries(address(mockAdapter), maturity, address(0));
        poolManager.deployPool("Sense Pool", 0.051 ether, 1 ether, AddressBook.MASTER_ORACLE);
        vm.expectRevert(abi.encodeWithSelector(Errors.TargetNotInFuse.selector));
        poolManager.queueSeries(address(mockAdapter), maturity, address(0));
        PoolManager.AssetParams memory params = PoolManager.AssetParams({
            irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
            reserveFactor: 0.1 ether,
            collateralFactor: 0.5 ether
        });
        poolManager.setParams("TARGET_PARAMS", params);
        poolManager.addTarget(address(target), address(mockAdapter));
        poolManager.queueSeries(address(mockAdapter), maturity, address(0));
    }
    function testMainnetAddSeries() public {
        uint256 maturity = _getValidMaturity();
        _initSeries(maturity);
        poolManager.deployPool("Sense Pool", 0.051 ether, 1 ether, AddressBook.MASTER_ORACLE);
        PoolManager.AssetParams memory paramsTarget = PoolManager.AssetParams({
            irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
            reserveFactor: 0.1 ether,
            collateralFactor: 0.5 ether
        });
        poolManager.setParams("TARGET_PARAMS", paramsTarget);
        address cTarget = poolManager.addTarget(address(target), address(mockAdapter));
        address pool = spaceFactory.create(address(mockAdapter), maturity);
        vm.expectRevert(abi.encodeWithSelector(Errors.SeriesNotQueued.selector));
        poolManager.addSeries(address(mockAdapter), maturity);
        poolManager.queueSeries(address(mockAdapter), maturity, pool);
        vm.expectRevert(abi.encodeWithSelector(Errors.PTParamsNotSet.selector));
        poolManager.addSeries(address(mockAdapter), maturity);
        poolManager.setParams(
            "PT_PARAMS",
            PoolManager.AssetParams({
                irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
                reserveFactor: 0.1 ether,
                collateralFactor: 0.5 ether
            })
        );
        poolManager.setParams(
            "LP_TOKEN_PARAMS",
            PoolManager.AssetParams({
                irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
                reserveFactor: 0.1 ether,
                collateralFactor: 0.5 ether
            })
        );
        (address cPT, address cLPToken) = poolManager.addSeries(address(mockAdapter), maturity);
        ComptrollerLike comptroller = ComptrollerLike(poolManager.comptroller());
        assertTrue(cPT != address(0));
        assertTrue(cLPToken != address(0));
        address[] memory cTokens = new address[](3);
        cTokens[0] = address(cTarget);
        cTokens[1] = address(cPT);
        cTokens[2] = address(cLPToken);
        ComptrollerLike(comptroller).enterMarkets(cTokens);
        uint256 TARGET_IN = 1.1e18;
        Token(MockSpacePool(pool).target()).mint(address(balancerVault), 1e18);
        MockSpacePool(pool).mint(address(this), 1e18);
        target.mint(address(this), TARGET_IN);
        target.approve(cTarget, TARGET_IN);
        uint256 originalTargetBalance = target.balanceOf(address(this));
        uint256 err = CToken(cTarget).mint(TARGET_IN);
        assertEq(err, 0);
        assertEq(
            (Token(cTarget).balanceOf(address(this)) * CToken(cTarget).exchangeRateCurrent()) /
                10**CToken(cTarget).decimals(),
            TARGET_IN
        );
        err = ComptrollerLike(comptroller).borrowAllowed(address(cPT), address(this), 1e18);
        assertEq(err, 4);
        vm.expectRevert("borrow is paused");
        ComptrollerLike(comptroller).borrowAllowed(address(cLPToken), address(this), 1e18);
        err = CToken(cTarget).redeem(Token(cTarget).balanceOf(address(this)));
        assertEq(err, 0);
        assertEq(target.balanceOf(address(this)), originalTargetBalance);
    }
    function testMainnetAdminPassthrough() public {
        poolManager.deployPool("Sense Pool", 0.051 ether, 1 ether, AddressBook.MASTER_ORACLE);
        PoolManager.AssetParams memory params = PoolManager.AssetParams({
            irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
            reserveFactor: 0.1 ether,
            collateralFactor: 0.5 ether
        });
        poolManager.setParams("TARGET_PARAMS", params);
        address underlying = mockAdapter.underlying();
        address[] memory underlyings = new address[](2);
        underlyings[0] = address(target);
        underlyings[1] = underlying;
        PriceOracle[] memory oracles = new PriceOracle[](2);
        oracles[0] = PriceOracle(poolManager.targetOracle());
        oracles[1] = PriceOracle(poolManager.masterOracle());
        poolManager.execute(
            poolManager.underlyingOracle(),
            0,
            abi.encodeWithSignature("setUnderlying(address,address)", underlying, address(mockAdapter)),
            gasleft() - 100000
        );
        poolManager.execute(
            poolManager.targetOracle(),
            0,
            abi.encodeWithSignature("setTarget(address,address)", address(target), address(mockAdapter)),
            gasleft() - 100000
        );
        poolManager.execute(
            poolManager.masterOracle(),
            0,
            abi.encodeWithSignature("add(address[],address[])", underlyings, oracles),
            gasleft() - 100000
        );
        bytes memory constructorData = abi.encode(
            target,
            poolManager.comptroller(),
            0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
            target.name(),
            target.symbol(),
            poolManager.cERC20Impl(),
            hex"", 
            0.1 ether,
            0 
        );
        bool success = poolManager.execute(
            poolManager.comptroller(),
            0,
            abi.encodeWithSignature("_deployMarket(bool,bytes,uint256)", false, constructorData, 0.5 ether),
            gasleft() - 100000
        );
        assertTrue(success);
        vm.expectRevert();
        poolManager.addTarget(address(target), address(mockAdapter));
        address cTarget = ComptrollerLike(poolManager.comptroller()).cTokensByUnderlying(address(target));
        vm.roll(1);
        success = poolManager.execute(
            poolManager.comptroller(),
            0,
            abi.encodeWithSignature("_unsupportMarket(address)", cTarget),
            gasleft() - 100000
        );
        assertTrue(success);
        poolManager.addTarget(address(target), address(mockAdapter));
    }
    function _getValidMaturity() internal view returns (uint256 maturity) {
        (uint256 year, uint256 month, ) = DateTimeFull.timestampToDate(block.timestamp + 10 weeks);
        maturity = DateTimeFull.timestampFromDateTime(year, month, 1, 0, 0, 0);
    }
    function _initSeries(uint256 maturity) internal {
        stake.mint(address(this), 1000 ether);
        stake.approve(address(divider), 1000 ether);
        divider.initSeries(address(mockAdapter), maturity, address(this));
    }
}