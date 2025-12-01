pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import {DSTest} from "@sense-finance/v1-core/src/tests/test-helpers/test.sol";
import {MockDividerSpace, MockAdapterSpace, ERC20Mintable} from "./utils/Mocks.sol";
import {Vm} from "forge-std/Vm.sol";
import {User} from "./utils/User.sol";
import {Vault, IVault, IWETH, IAuthorizer, IAsset, IProtocolFeesCollector} from "@balancer-labs/v2-vault/contracts/Vault.sol";
import {IPoolSwapStructs} from "@balancer-labs/v2-vault/contracts/interfaces/IPoolSwapStructs.sol";
import {Authentication} from "@balancer-labs/v2-solidity-utils/contracts/helpers/Authentication.sol";
import {IERC20} from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import {Authorizer} from "@balancer-labs/v2-vault/contracts/Authorizer.sol";
import {FixedPoint} from "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import {IPriceOracle} from "../oracle/interfaces/IPriceOracle.sol";
import {SpaceFactory} from "../SpaceFactory.sol";
import {Space} from "../Space.sol";
import {Errors} from "../Errors.sol";
contract SpaceTest is DSTest {
    using FixedPoint for uint256;
    Vm internal constant vm = Vm(HEVM_ADDRESS);
    IWETH internal constant weth =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 public constant INTIAL_USER_BALANCE = 100e18;
    uint256 public constant INIT_SCALE = 1.1e18;
    Vault internal vault;
    Space internal space;
    SpaceFactory internal spaceFactory;
    MockDividerSpace internal divider;
    MockAdapterSpace internal adapter;
    uint256 internal maturity;
    ERC20Mintable internal pt;
    ERC20Mintable internal target;
    Authorizer internal authorizer;
    User internal jim;
    User internal ava;
    User internal sid;
    User internal sam;
    uint256 internal ts;
    uint256 internal g1;
    uint256 internal g2;
    function setUp() public {
        vm.warp(0);
        vm.roll(0);
        divider = new MockDividerSpace(18);
        adapter = new MockAdapterSpace(18);
        adapter.setScale(INIT_SCALE);
        ts = FixedPoint.ONE.divDown(FixedPoint.ONE * 31622400 * 10); 
        g1 = (FixedPoint.ONE * 950).divDown(FixedPoint.ONE * 1000);
        g2 = (FixedPoint.ONE * 1000).divDown(FixedPoint.ONE * 950);
        maturity = 15811200; 
        divider.initSeries(maturity);
        authorizer = new Authorizer(address(this));
        vault = new Vault(authorizer, weth, 0, 0);
        spaceFactory = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
        space = Space(spaceFactory.create(address(adapter), maturity));
        (address _pt, , , , , , , , ) = MockDividerSpace(divider).series(
            address(adapter),
            maturity
        );
        pt = ERC20Mintable(_pt);
        target = ERC20Mintable(adapter.target());
        pt.mint(address(this), INTIAL_USER_BALANCE);
        target.mint(address(this), INTIAL_USER_BALANCE);
        target.approve(address(vault), type(uint256).max);
        pt.approve(address(vault), type(uint256).max);
        jim = new User(vault, space, pt, target);
        pt.mint(address(jim), INTIAL_USER_BALANCE);
        target.mint(address(jim), INTIAL_USER_BALANCE);
        ava = new User(vault, space, pt, target);
        pt.mint(address(ava), INTIAL_USER_BALANCE);
        target.mint(address(ava), INTIAL_USER_BALANCE);
        sid = new User(vault, space, pt, target);
        pt.mint(address(sid), INTIAL_USER_BALANCE);
        target.mint(address(sid), INTIAL_USER_BALANCE);
        sam = new User(vault, space, pt, target);
    }
    function testDeployPoolHasParams() public {
        address pt = MockDividerSpace(divider).pt(address(adapter), maturity);
        Space pool = new Space(
            vault,
            address(adapter),
            maturity,
            pt,
            ts,
            g1,
            g2,
            true
        );
        uint256 pti = pt < address(target) ? 0 : 1;
        assertEq(pool.adapter(), address(adapter));
        assertEq(pool.maturity(), maturity);
        assertEq(pool.pti(), pti);
        assertEq(pool.ts(), ts);
        assertEq(pool.g1(), g1);
        assertEq(pool.g2(), g2);
        assertEq(pool.name(), "Sense Space 4th Oct 2021 cDAI Sense Principal Token, A2");
        assertEq(pool.symbol(), "SPACE-sP-cDAI:04-10-2021:2");
    }
    function testJoinOnce() public {
        jim.join();
        assertEq(target.balanceOf(address(jim)), 99e18);
        assertClose(
            space.balanceOf(address(jim)),
            uint256(1e18).mulDown(INIT_SCALE),
            1e6
        );
        assertEq(pt.balanceOf(address(jim)), 100e18);
    }
    function testJoinMultiNoSwaps() public {
        jim.join();
        jim.join();
        assertEq(target.balanceOf(address(jim)), 98e18);
        assertClose(
            space.balanceOf(address(jim)),
            uint256(2e18).mulDown(INIT_SCALE),
            1e6
        );
        assertEq(pt.balanceOf(address(jim)), 100e18);
    }
    function testSimpleSwapIn() public {
        jim.join();
        try jim.swapIn(false, 1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.SWAP_TOO_SMALL);
        }
        uint256 targetOt = jim.swapIn(true);
        uint256 expectedTargetOut = 860452261775322692;
        assertEq(pt.balanceOf(address(jim)), 99e18);
        assertEq(targetOt, expectedTargetOut);
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        (uint256 pti, uint256 targeti) = space.getIndices();
        assertEq(balances[pti], 1e18);
        assertEq(balances[targeti], 1e18 - expectedTargetOut);
        try jim.swapIn(false) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.NEGATIVE_RATE);
        }
        uint256 ptOut = jim.swapIn(false, 0.5e18);
        uint256 expectedPTOut = 591079133821352896;
        assertEq(
            target.balanceOf(address(jim)),
            99e18 + expectedTargetOut - 0.5e18
        );
        assertEq(ptOut, expectedPTOut);
    }
    function testSimpleSwapsOut() public {
        jim.join();
        try jim.swapOut(false, 1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.NEGATIVE_RATE);
        }
        uint256 ptsIn = jim.swapOut(true, 0.1e18);
        uint256 expectedPTIn = 110582918254120990; 
        assertEq(target.balanceOf(address(jim)), 99e18 + 0.1e18);
        assertEq(ptsIn, expectedPTIn);
    }
    function testExitOnce() public {
        jim.join();
        jim.exit(space.balanceOf(address(jim)));
        assertEq(pt.balanceOf(address(jim)), 100e18);
        assertEq(space.balanceOf(address(jim)), 0);
        assertClose(target.balanceOf(address(jim)), 100e18, 1e6);
    }
    function testExitRounding() public {
        vm.roll(0);
        jim.join();
        vm.roll(1);
        jim.exit(space.balanceOf(address(jim)));
        uint256 preSupply = space.totalSupply();
        assertEq(preSupply, space.MINIMUM_BPT());
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        assertEq(
            balances[1 - space.pti()],
            space.MINIMUM_BPT().divDown(INIT_SCALE)
        );
        vm.roll(2);
        uint256 TARGET_IN = 50e18;
        sid.join(0, TARGET_IN);
        uint256 joinedTargetInUnderlying = TARGET_IN.mulDown(INIT_SCALE);
        uint256 postSupply = space.totalSupply();
        assertEq(postSupply, preSupply + joinedTargetInUnderlying);
        vm.roll(3);
        sid.swapIn(true, 20e18);
    }
    function testGrowingTargetReservesWithStableBptSupply() public {
        vm.roll(0);
        adapter.setScale(1.1e18);
        jim.join(0, 10e18);
        vm.roll(1);
        sid.swapIn(true, 0.05e18);
        uint256 tOut;
        for (uint256 i = 0; i < 20; i++) {
            uint256 _tOut = sid.swapIn(true, 3e18);
            assertGt(_tOut, tOut);
            tOut = _tOut;
            sid.swapOut(false, 3e18);
        }
        vm.roll(2);
        jim.exit(space.balanceOf(address(jim)));
        assertGt(target.balanceOf(address(jim)), INTIAL_USER_BALANCE);
        assertGt(pt.balanceOf(address(jim)), INTIAL_USER_BALANCE);
        vm.roll(3);
    }
    function testJoinSwapExit() public {
        jim.join();
        jim.swapOut(true, 0.1e18);
        jim.exit(space.balanceOf(address(jim)));
        assertClose(pt.balanceOf(address(jim)), 100e18, 1e6);
        assertEq(space.balanceOf(address(jim)), 0);
        assertClose(target.balanceOf(address(jim)), 100e18, 1e6);
    }
    function testMultiPartyJoinSwapExit() public {
        jim.join();
        assertEq(target.balanceOf(address(jim)), 99e18);
        sid.swapIn(true, 0.8e18);
        ava.join(0.8e18, 0.8e18);
        assertGe(target.balanceOf(address(ava)), 99e18);
        assertEq(pt.balanceOf(address(ava)), 99.2e18);
        sid.swapIn(true, 0.2e18);
        uint256 targetPreJoin = target.balanceOf(address(ava));
        ava.join();
        assertGe(target.balanceOf(address(ava)), 99e18);
        assertGt(
            100e18 - targetPreJoin,
            targetPreJoin - target.balanceOf(address(ava))
        );
        assertEq(pt.balanceOf(address(ava)), 98.2e18);
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        (uint256 pti, uint256 targeti) = space.getIndices();
        uint256 targetPerPrincipal = (balances[targeti] * 1e18) / balances[pti];
        assertEq(
            target.balanceOf(address(ava)),
            targetPreJoin - targetPerPrincipal
        );
        jim.exit(space.balanceOf(address(jim)));
        ava.exit(space.balanceOf(address(ava)));
        try sid.swapIn(true, 1e12) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "BAL#001");
        }
        try sid.swapOut(false, 1e12) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "BAL#001");
        }
        assertClose(target.balanceOf(address(jim)), 99.2e18, 1e17);
        assertClose(target.balanceOf(address(ava)), 99.9e18, 1e17);
        assertClose(pt.balanceOf(address(jim)), 100.9e18, 1e12);
        assertClose(pt.balanceOf(address(ava)), 100.1e18, 1e12);
    }
    function testMinBptOut() public {
        uint256 minBpt = space.MINIMUM_BPT();
        vm.expectRevert("SNS#108");
        jim.join(0, 1e18, INIT_SCALE.mulDown(1e18).sub(minBpt) + 1);
        jim.join(0, 1e18, INIT_SCALE.mulDown(1e18).sub(minBpt));
        sid.swapIn(true, 0.8e18);
        uint256 preBpt = space.balanceOf(address(jim));
        jim.join(1e18, 1e18);
        uint256 newBpt = space.balanceOf(address(jim)) - preBpt;
        jim.exit(newBpt);
        vm.expectRevert("SNS#108");
        jim.join(1e18, 1e18, newBpt + 2); 
        jim.join(1e18, 1e18, newBpt);
    }
    function testSpaceFees() public {
        jim.join(0, 20e18);
        sid.swapIn(true, 4e18);
        jim.join(20e18, 20e18);
        uint256 ptPrice = sid.swapIn(true, 0.0001e18).divDown(0.0001e18);
        uint256 balance = 100e18;
        uint256 startingPositionValue = balance + balance.mulDown(ptPrice);
        uint256 targetInFor1PrincipalOut = 0;
        for (uint256 i = 0; i < 20; i++) {
            uint256 _targetInFor1PrincipalOut = ava.swapOut(false);
            assertGt(_targetInFor1PrincipalOut, targetInFor1PrincipalOut);
            targetInFor1PrincipalOut = _targetInFor1PrincipalOut;
            ava.swapIn(true, 1e18);
        }
        uint256 ptInFor1TargetOut = 0;
        for (uint256 i = 0; i < 20; i++) {
            uint256 _ptInFor1TargetOut = ava.swapOut(true);
            assertGt(_ptInFor1TargetOut, ptInFor1TargetOut);
            ptInFor1TargetOut = _ptInFor1TargetOut;
            ava.swapIn(false, 1e18);
        }
        uint256 targetOutFor1PrincipalIn = type(uint256).max;
        for (uint256 i = 0; i < 20; i++) {
            uint256 _targetOutFor1PrincipalIn = ava.swapIn(true);
            assertLt(_targetOutFor1PrincipalIn, targetOutFor1PrincipalIn);
            targetOutFor1PrincipalIn = _targetOutFor1PrincipalIn;
            ava.swapIn(false, _targetOutFor1PrincipalIn);
        }
        uint256 ptOutFor1TargetIn = type(uint256).max;
        for (uint256 i = 0; i < 20; i++) {
            uint256 _ptOutFor1TargetIn = ava.swapIn(false);
            assertLt(_ptOutFor1TargetIn, ptOutFor1TargetIn);
            ptOutFor1TargetIn = _ptOutFor1TargetIn;
            ava.swapIn(true, _ptOutFor1TargetIn);
        }
        jim.exit(space.balanceOf(address(jim)));
        uint256 currentPositionValue = target.balanceOf(address(jim)) +
            pt.balanceOf(address(jim)).mulDown(ptPrice);
        assertGt(currentPositionValue, startingPositionValue);
    }
    function testApproachesOne() public {
        jim.join(0, 10e18);
        sid.swapIn(true, 5.5e18);
        jim.join(10e18, 10e18);
        vm.warp(maturity - 1);
        assertClose(sid.swapIn(true).mulDown(adapter.scale()), 1e18, 1e11);
        assertClose(
            sid.swapIn(false, uint256(1e18).divDown(adapter.scale())),
            1e18,
            1e11
        );
    }
    function testConstantSumAfterMaturity() public {
        jim.join(0, 10e18);
        sid.swapIn(true, 5.5e18);
        jim.join(10e18, 10e18);
        vm.warp(maturity + 1);
        assertClose(sid.swapIn(true).mulDown(adapter.scale()), 1e18, 1e7);
        assertClose(
            sid.swapIn(false, uint256(1e18).divDown(adapter.scale())),
            1e18,
            1e7
        );
    }
    function testCantJoinAfterMaturity() public {
        vm.warp(maturity + 1);
        try jim.join(0, 10e18) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.POOL_PAST_MATURITY);
        }
    }
    function testProtocolFees() public {
        IProtocolFeesCollector protocolFeesCollector = vault
            .getProtocolFeesCollector();
        bytes32 actionId = Authentication(address(protocolFeesCollector))
            .getActionId(protocolFeesCollector.setSwapFeePercentage.selector);
        authorizer.grantRole(actionId, address(this));
        protocolFeesCollector.setSwapFeePercentage(0.1e18);
        assertEq(space.balanceOf(address(protocolFeesCollector)), 0);
        jim.join(0, 10e18);
        jim.swapIn(true, 5.5e18);
        jim.join(10e18, 10e18);
        ava.join(10e18, 10e18);
        uint256 NUM_WASH_TRADES = 6;
        emit log_named_uint("PT", pt.balanceOf(address(ava)));
        emit log_named_uint("target", target.balanceOf(address(ava)));
        uint256 feeControllerBPTPre = space.balanceOf(
            address(protocolFeesCollector)
        );
        uint256 expectedFeesPaid = 0;
        for (uint256 i = 0; i < NUM_WASH_TRADES; i++) {
            uint256 targetIn = sid.swapOut(false);
            uint256 idealYield = 1e18 - (targetIn * 0.95e18) / 1e18;
            uint256 feeOnYield = (idealYield * 0.05e18) / 1e18;
            expectedFeesPaid += feeOnYield;
            uint256 targetOut = sid.swapIn(true);
            idealYield = 1e18 - (targetOut * 0.95e18) / 1e18;
            feeOnYield = (idealYield * 0.05e18) / 1e18;
            expectedFeesPaid += feeOnYield;
        }
        assertEq(
            space.balanceOf(address(protocolFeesCollector)),
            feeControllerBPTPre
        );
        ava.exit(space.balanceOf(address(ava)));
        uint256 feeControllerNewBPT = space.balanceOf(
            address(protocolFeesCollector)
        ) - feeControllerBPTPre;
        vm.prank(
            address(protocolFeesCollector),
            address(protocolFeesCollector)
        );
        space.transfer(address(sam), feeControllerNewBPT);
        sam.exit(space.balanceOf(address(sam)));
        emit log_named_uint("sam PTs", pt.balanceOf(address(sam)));
        emit log_named_uint("sam target", target.balanceOf(address(sam)));
        emit log_named_uint("expectedFeesPaid", expectedFeesPaid);
        assertEq(pt.balanceOf(address(sid)), 100e18);
        assertLt(target.balanceOf(address(sid)), 100e18);
        emit log_named_uint("lost", 100e18 - target.balanceOf(address(sid)));
    }
    function testTinySwaps() public {
        jim.join(0, 10e18);
        sid.swapIn(true, 5.5e18);
        jim.join(10e18, 10e18);
        try sid.swapIn(true, 1e6) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.SWAP_TOO_SMALL);
        }
        try sid.swapIn(false, 1e6) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, Errors.SWAP_TOO_SMALL);
        }
        assertGt(sid.swapOut(true, 1e6), 2e6);
        assertGt(sid.swapOut(false, 1e6), 2e6);
    }
    function testJoinDifferentScaleValues() public {
        jim.join(0, 10e18);
        sid.swapIn(true, 5.5e18);
        adapter.setScale(0);
        uint256 initScale = adapter.scale();
        uint256 targetOutForOnePrincipalInit = jim.swapIn(true);
        jim.swapIn(false, targetOutForOnePrincipalInit);
        ava.join();
        uint256 bptFromJoin = space.balanceOf(address(ava));
        uint256 targetInFromJoin = INTIAL_USER_BALANCE -
            target.balanceOf(address(ava));
        uint256 ptInFromJoin = INTIAL_USER_BALANCE - pt.balanceOf(address(ava));
        vm.warp(1 days);
        uint256 scale1Week = adapter.scale();
        ava.join();
        assertClose(
            bptFromJoin,
            space.balanceOf(address(ava)) - bptFromJoin,
            1e3
        );
        assertClose(
            targetInFromJoin * 2,
            INTIAL_USER_BALANCE - target.balanceOf(address(ava)),
            1e3
        );
        assertClose(
            ptInFromJoin * 2,
            INTIAL_USER_BALANCE - pt.balanceOf(address(ava)),
            1e3
        );
        ava.exit(space.balanceOf(address(ava)));
        uint256 targetOutForOnePrincipal1Week = jim.swapIn(true);
        assertGt(targetOutForOnePrincipalInit, targetOutForOnePrincipal1Week);
        assertClose(
            targetOutForOnePrincipalInit,
            targetOutForOnePrincipal1Week.mulDown(
                scale1Week.divDown(initScale)
            ),
            1e15
        );
    }
    function testDifferentDecimals() public {
        MockDividerSpace divider = new MockDividerSpace(8);
        divider.initSeries(maturity);
        MockAdapterSpace adapter = new MockAdapterSpace(9);
        adapter.setScale(INIT_SCALE);
        SpaceFactory spaceFactory = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
        Space space = Space(spaceFactory.create(address(adapter), maturity));
        (address _pt, , , , , , , , ) = MockDividerSpace(divider).series(
            address(adapter),
            maturity
        );
        ERC20Mintable pt = ERC20Mintable(_pt);
        ERC20Mintable _target = ERC20Mintable(adapter.target());
        User max = new User(vault, space, pt, _target);
        _target.mint(address(max), 100e9);
        pt.mint(address(max), 100e8);
        User eve = new User(vault, space, pt, _target);
        _target.mint(address(eve), 100e9);
        pt.mint(address(eve), 100e8);
        max.join(0, 1e9);
        assertEq(_target.balanceOf(address(max)), 99e9);
        eve.swapIn(true, 1e8);
        max.join(1e8, 1e9);
        assertEq(pt.balanceOf(address(max)), 99e8);
        jim.join(0, 1e18);
        sid.swapIn(true, 1e18);
        jim.join(1e18, 1e18);
        uint256 jimTargetBalance = target.balanceOf(address(jim)) /
            10**(18 - _target.decimals());
        assertClose(_target.balanceOf(address(max)), jimTargetBalance, 1e6);
    }
    function testDifferentDecimalsMinReserves() public {
        MockDividerSpace divider = new MockDividerSpace(8);
        divider.initSeries(maturity);
        MockAdapterSpace adapter = new MockAdapterSpace(9);
        adapter.setScale(INIT_SCALE);
        SpaceFactory spaceFactory = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
        Space space = Space(spaceFactory.create(address(adapter), maturity));
        (address _pt, , , , , , , , ) = MockDividerSpace(divider).series(
            address(adapter),
            maturity
        );
        ERC20Mintable pt = ERC20Mintable(_pt);
        ERC20Mintable _target = ERC20Mintable(adapter.target());
        User max = new User(vault, space, pt, _target);
        _target.mint(address(max), 100e9);
        pt.mint(address(max), 100e8);
        User eve = new User(vault, space, pt, _target);
        _target.mint(address(eve), 100e9);
        pt.mint(address(eve), 100e8);
        max.join(0, 5e9);
        eve.swapIn(true, 1e8);
        eve.swapIn(true, 1e8);
        eve.swapOut(false, 1e8);
        emit log_named_uint("bpt", space.totalSupply());
        max.exit(space.balanceOf(address(max)));
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        assertEq(balances[0], 1);
        assertEq(balances[1], 1);
        emit log_named_uint("bpt", space.totalSupply());
        max.join(5e8, 5e9);
        (, balances, ) = vault.getPoolTokens(space.getPoolId());
        assertEq(balances[0], 500000001);
        assertEq(balances[1], 500000001);
        emit log_named_uint("bpt", space.totalSupply());
        vm.expectRevert("BAL#001");
        eve.swapIn(true, 1e8);
        assertEq(space.totalSupply(), 500000001000000);
    }
    function testFailSmallDecimalsGuardInvalidState(
        uint64 joinAmt,
        uint64 swapInAmt1,
        uint64 swapInAmt2
    ) public {
        vm.assume(joinAmt / 2 > swapInAmt1);
        vm.assume(swapInAmt1 / 2 > swapInAmt2);
        vm.assume(swapInAmt2 >= 1e7);
        MockDividerSpace divider = new MockDividerSpace(8);
        divider.initSeries(maturity);
        MockAdapterSpace adapter = new MockAdapterSpace(8);
        SpaceFactory spaceFactory = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
        Space space = Space(spaceFactory.create(address(adapter), maturity));
        (address _pt, , , , , , , , ) = MockDividerSpace(divider).series(
            address(adapter),
            maturity
        );
        ERC20Mintable pt = ERC20Mintable(_pt);
        ERC20Mintable _target = ERC20Mintable(adapter.target());
        User max = new User(vault, space, pt, _target);
        _target.mint(address(max), uint256(joinAmt) * 2);
        pt.mint(address(max), uint256(joinAmt) * 2);
        User eve = new User(vault, space, pt, _target);
        pt.mint(address(eve), swapInAmt1 + swapInAmt2);
        max.join(0, joinAmt);
        eve.swapIn(true, swapInAmt1);
        max.exit(space.balanceOf(address(max)));
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        assertTrue(
            !((balances[0] == 0 || balances[0] == 1) &&
                (balances[1] == 0 || balances[1] == 1))
        );
        max.join(joinAmt, joinAmt);
        eve.swapIn(true, swapInAmt2);
    }
    function testSmallDecimalsGuardInvalidState(
        uint64 joinAmt,
        uint64 swapInAmt1,
        uint64 swapInAmt2
    ) public {
        vm.assume(joinAmt / 2 > swapInAmt1);
        vm.assume(swapInAmt1 / 2 > swapInAmt2);
        vm.assume(swapInAmt2 >= 1e7);
        MockDividerSpace divider = new MockDividerSpace(8);
        divider.initSeries(maturity);
        MockAdapterSpace adapter = new MockAdapterSpace(8);
        SpaceFactory spaceFactory = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
        Space space = Space(spaceFactory.create(address(adapter), maturity));
        (address _pt, , , , , , , , ) = MockDividerSpace(divider).series(
            address(adapter),
            maturity
        );
        ERC20Mintable _target = ERC20Mintable(adapter.target());
        User max = new User(vault, space, ERC20Mintable(_pt), _target);
        _target.mint(address(max), uint256(joinAmt) * 2);
        ERC20Mintable(_pt).mint(address(max), uint256(joinAmt) * 2);
        User eve = new User(vault, space, ERC20Mintable(_pt), _target);
        ERC20Mintable(_pt).mint(address(eve), swapInAmt1 + swapInAmt2);
        User sia = new User(vault, space, ERC20Mintable(_pt), _target);
        _target.mint(address(sia), 1e8);
        sia.join(0, 1e8);
        max.join(0, joinAmt);
        eve.swapIn(true, swapInAmt1);
        max.exit(space.balanceOf(address(max)));
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        assertTrue(
            !((balances[0] == 0 || balances[0] == 1) &&
                (balances[1] == 0 || balances[1] == 1))
        );
        max.join(joinAmt, joinAmt);
        eve.swapIn(true, swapInAmt2);
    }
    function testNonMonotonicScale() public {
        adapter.setScale(1e18);
        jim.join(0, 10e18);
        sid.swapIn(true, 5.5e18);
        jim.join(10e18, 10e18);
        adapter.setScale(1.5e18);
        jim.join(10e18, 10e18);
        uint256 targetOut1 = sid.swapIn(true, 5.5e18);
        adapter.setScale(1e18);
        jim.join(10e18, 10e18);
        uint256 targetOut2 = sid.swapIn(true, 5.5e18);
        adapter.setScale(0.5e18);
        jim.join(10e18, 10e18);
        uint256 targetOut3 = sid.swapIn(true, 5.5e18);
        assertGt(targetOut3, targetOut2);
        assertGt(targetOut2, targetOut1);
    }
    function testOnSwapStorageUpdates() public {
        jim.join(0, 10e18);
        sid.swapIn(true, 2e18);
        uint256 BLOCK = 1;
        uint256 TS = 111;
        vm.roll(BLOCK);
        vm.warp(TS);
        uint256 pti = space.pti();
        bytes32 poolId = space.getPoolId();
        (, uint256[] memory balances, ) = vault.getPoolTokens(poolId);
        vm.record();
        space.onSwap(
            IPoolSwapStructs.SwapRequest({
                kind: IVault.SwapKind.GIVEN_OUT,
                tokenIn: IERC20(address(target)),
                tokenOut: IERC20(address(pt)),
                amount: 1e18,
                poolId: poolId,
                lastChangeBlock: 0,
                from: address(0),
                to: address(0),
                userData: ""
            }),
            balances[1 - pti],
            balances[pti]
        );
        (, bytes32[] memory writes) = vm.accesses(address(space));
        assertEq(writes.length, 0);
        (,,,,,, uint256 sampleTS) = space.getSample(0);
        assertEq(sampleTS, 0);
        sid.swapIn(true, 1e18);
        (, writes) = vm.accesses(address(space));
        assertEq(writes.length, 1);
        (,,,,,, sampleTS) = space.getSample(0);
        assertEq(sampleTS, TS);
    }
    function testFuzzOnSwapStorageUpdates(uint8[2] calldata envdata, uint64[2] calldata pooldata) public {
        vm.assume(pooldata[0] / 2 > pooldata[1]);
        vm.assume(pooldata[1] >= 1e7);
        target.mint(address(jim), pooldata[0]);
        jim.join(0, pooldata[0]);
        pt.mint(address(sid), pooldata[1]);
        sid.swapIn(true, pooldata[1]);
        vm.roll(envdata[0]);
        vm.warp(envdata[1]);
        uint256 pti = space.pti();
        bytes32 poolId = space.getPoolId();
        (, uint256[] memory balances, ) = vault.getPoolTokens(poolId);
        vm.record();
        space.onSwap(
            IPoolSwapStructs.SwapRequest({
                kind: IVault.SwapKind.GIVEN_OUT,
                tokenIn: IERC20(address(target)),
                tokenOut: IERC20(address(pt)),
                amount: 1e6,
                poolId: poolId,
                lastChangeBlock: 0,
                from: address(0),
                to: address(0),
                userData: ""
            }),
            balances[1 - pti],
            balances[pti]
        );
        (, bytes32[] memory writes) = vm.accesses(address(space));
        assertEq(writes.length, 0);
    }
    function testPairOracle() public {
        adapter.setScale(1e18);
        vm.warp(0 hours);
        vm.roll(0);
        spaceFactory.setParams(ts, FixedPoint.ONE, FixedPoint.ONE, true);
        uint256 NEW_MATURITY = maturity / 2;
        divider.initSeries(NEW_MATURITY);
        space = Space(spaceFactory.create(address(adapter), NEW_MATURITY));
        User tim = new User(vault, space, pt, target);
        pt.mint(address(tim), INTIAL_USER_BALANCE);
        target.mint(address(tim), INTIAL_USER_BALANCE);
        User pam = new User(vault, space, pt, target);
        pt.mint(address(pam), INTIAL_USER_BALANCE);
        target.mint(address(pam), INTIAL_USER_BALANCE);
        tim.join(0, 10e18);
        pam.swapIn(true, 2e18);
        uint256 sampleTs;
        (, , , , , , sampleTs) = space.getSample(1);
        assertEq(sampleTs, 0);
        vm.warp(1 hours);
        vm.roll(1);
        tim.join(1e18, 1e18);
        (, , , , , , sampleTs) = space.getSample(1);
        assertEq(sampleTs, 1 hours);
        vm.warp(2 hours);
        vm.roll(2);
        tim.join(10, 10);
        (, , , , , , sampleTs) = space.getSample(2);
        assertEq(sampleTs, 2 hours);
        uint256 targetOut = tim.swapIn(true, 1e12);
        uint256 pTInstSpotPrice = targetOut.divDown(1e12);
        uint256 twapPeriod = 1 hours;
        IPriceOracle.OracleAverageQuery[]
            memory queries = new IPriceOracle.OracleAverageQuery[](1);
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: twapPeriod,
            ago: 0
        });
        uint256[] memory results = space.getTimeWeightedAverage(queries);
        uint256 pTPrice = results[0];
        assertClose(pTPrice, pTInstSpotPrice, 6e14);
        vm.warp(20 hours);
        vm.roll(20);
        tim.join(10, 10);
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: twapPeriod,
            ago: 0
        });
        results = space.getTimeWeightedAverage(queries);
        pTPrice = results[0];
        targetOut = tim.swapIn(true, 1e12);
        pTInstSpotPrice = targetOut.divDown(1e12);
        assertClose(pTPrice, pTInstSpotPrice, 6e14);
        twapPeriod = 22 hours;
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: twapPeriod,
            ago: 0
        });
        try space.getTimeWeightedAverage(queries) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "BAL#312");
        }
        for (uint256 i = 3; i < 23; i++) {
            vm.warp(i * 1 hours);
            vm.roll(i);
            tim.join(10, 10);
        }
        (, , , , , , sampleTs) = space.getSample(space.getTotalSamples() - 1);
        assertEq(sampleTs, 19 hours);
        for (uint256 i = 23; i < 42; i++) {
            vm.warp(i * 1 hours);
            vm.roll(i);
            tim.join(10, 10);
        }
        (, , , , , , sampleTs) = space.getSample(space.getTotalSamples() - 1);
        assertEq(sampleTs, 39 hours);
    }
    function testPairOracleNoSamples() public {
        adapter.setScale(1e18);
        vm.warp(0 hours);
        vm.roll(0);
        jim.join(0, 10e18);
        sid.swapIn(true, 2e18);
        vm.warp(1 hours);
        vm.roll(1);
        jim.join(1e18, 1e18);
        uint256 twapPeriod = 1 hours;
        IPriceOracle.OracleAverageQuery[]
            memory queries = new IPriceOracle.OracleAverageQuery[](1);
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: twapPeriod,
            ago: 0
        });
        uint256[] memory results = space.getTimeWeightedAverage(queries);
        uint256 pTPricePre = results[0];
        vm.warp(5 hours);
        queries = new IPriceOracle.OracleAverageQuery[](1);
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: twapPeriod,
            ago: 0
        });
        results = space.getTimeWeightedAverage(queries);
        uint256 pTPrice = results[0];
        assertEq(pTPricePre, pTPrice);
    }
    function testImpliedRateFromPriceUtil() public {
        adapter.setScale(1e18);
        assertClose(
            space.getImpliedRateFromPrice(0.5e18),
            1048575000000000000000000,
            1e18
        );
        assertClose(
            space.getImpliedRateFromPrice(0.9e18),
            7225263339969966000,
            1e18
        );
        assertClose(
            space.getImpliedRateFromPrice(0.98e18),
            497885049771156200,
            1e18
        );
        vm.warp(7905600);
        assertClose(
            space.getImpliedRateFromPrice(0.9e18),
            66654957011853880000,
            1e18
        );
        assertClose(
            space.getImpliedRateFromPrice(0.98e18),
            1243659622327939600,
            1e18
        );
        vm.warp(13834800);
        assertClose(
            space.getImpliedRateFromPrice(0.9e18),
            20950696665886087000000000,
            1e18
        );
        assertClose(
            space.getImpliedRateFromPrice(0.98e18),
            24341241586778587000,
            1e18
        );
        vm.warp(maturity);
        assertEq(space.getImpliedRateFromPrice(0.9e18), 0);
        vm.warp(0);
        adapter.setScale(2e18);
        assertClose(
            space.getImpliedRateFromPrice(0.45e18),
            7225263339969966000,
            1e18
        );
    }
    function testPriceFromImpliedRateUtil() public {
        adapter.setScale(1e18);
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.5e18)
            ),
            0.5e18,
            1e14
        );
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.9e18)
            ),
            0.9e18,
            1e14
        );
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.98e18)
            ),
            0.98e18,
            1e14
        );
        vm.warp(7905600);
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.9e18)
            ),
            0.9e18,
            1e14
        );
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.98e18)
            ),
            0.98e18,
            1e14
        );
        vm.warp(13834800);
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.9e18)
            ),
            0.9e18,
            1e14
        );
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.98e18)
            ),
            0.98e18,
            1e14
        );
        vm.warp(maturity);
        assertEq(space.getPriceFromImpliedRate(0.1e18), 1e18);
        vm.warp(0);
        adapter.setScale(2e18);
        assertClose(
            space.getPriceFromImpliedRate(
                space.getImpliedRateFromPrice(0.45e18)
            ),
            0.45e18,
            1e14
        );
    }
    function testFairBptPrice() public {
        adapter.setScale(1e18);
        vm.warp(0 hours);
        vm.roll(0);
        jim.join(0, 10e18);
        sid.swapIn(true, 2e18);
        try space.getFairBPTPrice(1 hours) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "BAL#312");
        }
        vm.warp(1 hours);
        vm.roll(1);
        jim.join(1e18, 1e18);
        vm.warp(2 hours);
        vm.roll(2);
        jim.join(1e18, 1e18);
        IPriceOracle.OracleAverageQuery[]
            memory queries = new IPriceOracle.OracleAverageQuery[](1);
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: 1 hours,
            ago: 120
        });
        uint256[] memory results = space.getTimeWeightedAverage(queries);
        uint256 fairPTPriceInTarget1 = results[0];
        uint256 theoFairBptValue1 = space.getFairBPTPrice(10 minutes);
        (, uint256[] memory balances, ) = vault.getPoolTokens(
            space.getPoolId()
        );
        uint256 spotBptValueFairPrice1 = balances[space.pti()]
            .mulDown(fairPTPriceInTarget1)
            .add(balances[1 - space.pti()])
            .divDown(space.totalSupply());
        assertClose(spotBptValueFairPrice1, theoFairBptValue1, 1e14);
        sid.swapIn(true, 4e18);
        queries = new IPriceOracle.OracleAverageQuery[](1);
        queries[0] = IPriceOracle.OracleAverageQuery({
            variable: IPriceOracle.Variable.PAIR_PRICE,
            secs: 1 hours,
            ago: 120
        });
        results = space.getTimeWeightedAverage(queries);
        uint256 fairPTPriceInTarget2 = results[0];
        assertEq(fairPTPriceInTarget1, fairPTPriceInTarget2);
        uint256 theoFairBptValue2 = space.getFairBPTPrice(10 minutes);
        assertClose(theoFairBptValue1, theoFairBptValue2, 2e15);
        (, balances, ) = vault.getPoolTokens(space.getPoolId());
        uint256 spotBptValueFairPrice2 = balances[space.pti()]
            .mulDown(fairPTPriceInTarget1)
            .add(balances[1 - space.pti()])
            .divDown(space.totalSupply());
        assertTrue(!isClose(spotBptValueFairPrice1, spotBptValueFairPrice2, 5e15));
    }
    function testFactorySetPoolSwap() public {
        SpaceFactory spaceFactory2 = new SpaceFactory(
            vault,
            address(divider),
            ts,
            g1,
            g2,
            true
        );
        address space2 = spaceFactory2.create(address(adapter), maturity);
        divider.initSeries(maturity + 1);
        spaceFactory.setPool(address(adapter), maturity + 1, space2);
        User user1 = new User(vault, Space(space2), ERC20Mintable(pt), ERC20Mintable(target));
        target.mint(address(user1), 2e18);
        pt.mint(address(user1), 1e18);
        user1.join(0, 2e18);
        user1.swapIn(true, 0.5e18);
        uint256 targetOut = user1.swapIn(true, 0.5e18);
        assertGt(targetOut, 0);
    }
}