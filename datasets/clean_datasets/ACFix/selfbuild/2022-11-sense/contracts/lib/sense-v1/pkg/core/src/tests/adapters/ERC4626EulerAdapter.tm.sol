pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { FixedMath } from "../../external/FixedMath.sol";
import { ERC4626Adapter } from "../../adapters/abstract/erc4626/ERC4626Adapter.sol";
import { BaseFactory } from "../../adapters/abstract/factories/BaseFactory.sol";
import { ERC4626Factory } from "../../adapters/abstract/factories/ERC4626Factory.sol";
import { EulerERC4626WrapperFactory } from "../../adapters/abstract/erc4626/yield-daddy/euler/EulerERC4626WrapperFactory.sol";
import { EulerERC4626 } from "../../adapters/abstract/erc4626/yield-daddy/euler/EulerERC4626.sol";
import { IEulerMarkets } from "@yield-daddy/src/euler/external/IEulerMarkets.sol";
import { IPriceFeed } from "../../adapters/abstract/IPriceFeed.sol";
import { MasterPriceOracle } from "../../adapters/implementations/oracles/MasterPriceOracle.sol";
import { ChainlinkPriceOracle } from "../../adapters/implementations/oracles/ChainlinkPriceOracle.sol";
import { Divider } from "../../Divider.sol";
import { Periphery } from "../../Periphery.sol";
import { AddressBook } from "../test-helpers/AddressBook.sol";
import { MockOracle } from "../test-helpers/mocks/fuse/MockOracle.sol";
import { Constants } from "../test-helpers/Constants.sol";
interface EulerERC4626Like {
    function eToken() external returns (address);
    function euler() external returns (address);
}
interface IEulerTokenLike {
    function deposit(uint256 subAccountId, uint256 amount) external;
    function balanceOfUnderlying(address) external returns (uint256);
}
contract ERC4626EulerAdapters is Test {
    using FixedMath for uint256;
    ERC4626 public target;
    ERC20 public underlying;
    uint256 public decimals;
    Divider public divider = Divider(AddressBook.DIVIDER_1_2_0);
    Periphery public periphery = Periphery(AddressBook.PERIPHERY_1_3_0);
    ERC4626Factory public factory = ERC4626Factory(AddressBook.NON_CROP_4626_FACTORY);
    ERC4626Adapter public adapter;
    EulerERC4626WrapperFactory public wFactory;
    uint16 public constant MODE = 0;
    uint64 public constant ISSUANCE_FEE = 0.01e18;
    uint256 public constant STAKE_SIZE = 1e18;
    uint256 public constant MIN_MATURITY = 2 weeks;
    uint256 public constant MAX_MATURITY = 14 weeks;
    uint256 public constant DEFAULT_GUARD = 100000 * 1e18;
    uint256 public constant INITIAL_BALANCE = 10**6;
    function setUp() public {
        wFactory = new EulerERC4626WrapperFactory(
            AddressBook.EULER,
            IEulerMarkets(AddressBook.EULER_MARKETS),
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT
        );
        target = wFactory.createERC4626(ERC20(AddressBook.USDC));
        decimals = target.decimals();
        underlying = ERC20(target.asset());
        assertEq(address(underlying), AddressBook.USDC);
        deal(address(underlying), address(this), 5 * 10**decimals);
        vm.prank(AddressBook.SENSE_ADMIN_MULTISIG);
        factory.supportTarget(address(target), true);
        adapter = ERC4626Adapter(periphery.deployAdapter(address(factory), address(target), ""));
    }
    function testMainnetERC4626AdapterScale() public {
        uint256 scale = target.convertToAssets(10**decimals) * 10**(18 - decimals);
        assertEq(adapter.scale(), scale);
    }
    function testMainnetGetUnderlyingPrice() public {
        uint256 price = IPriceFeed(AddressBook.RARI_ORACLE).price(AddressBook.USDC);
        assertEq(adapter.getUnderlyingPrice(), price);
    }
    function testMainnetUnwrapTarget() public {
        uint256 uBal = underlying.balanceOf(address(this));
        underlying.approve(address(adapter), uBal);
        adapter.wrapUnderlying(uBal);
        uint256 uBalanceBefore = underlying.balanceOf(address(this));
        uint256 tBalanceBefore = target.balanceOf(address(this));
        target.approve(address(adapter), tBalanceBefore);
        uint256 rate = target.convertToAssets(10**decimals);
        uint256 unwrapped = tBalanceBefore.fmul(rate, 10**decimals);
        adapter.unwrapTarget(tBalanceBefore);
        uint256 tBalanceAfter = target.balanceOf(address(this));
        uint256 uBalanceAfter = underlying.balanceOf(address(this));
        assertEq(tBalanceAfter, 0);
        assertApproxEqAbs(uBalanceBefore + unwrapped, uBalanceAfter);
    }
    function testMainnetWrapUnderlying() public {
        uint256 uBal = 10**decimals;
        underlying.approve(address(target), uBal);
        target.deposit(uBal, address(this));
        uint256 uBalanceBefore = underlying.balanceOf(address(this));
        uint256 tBalanceBefore = target.balanceOf(address(this));
        underlying.approve(address(adapter), uBalanceBefore);
        uint256 rate = target.convertToAssets(10**decimals);
        uint256 wrapped = uBalanceBefore.fdivUp(rate, 10**decimals);
        adapter.wrapUnderlying(uBalanceBefore);
        uint256 tBalanceAfter = target.balanceOf(address(this));
        uint256 uBalanceAfter = underlying.balanceOf(address(this));
        assertEq(uBalanceAfter, 0);
        assertApproxEqAbs(tBalanceBefore + wrapped, tBalanceAfter);
    }
    function testMainnetWrapUnwrap(uint256 wrapAmt) public {
        wrapAmt = bound(wrapAmt, 10, INITIAL_BALANCE);
        target.approve(address(adapter), type(uint256).max);
        underlying.approve(address(adapter), type(uint256).max);
        uint256 prebal = underlying.balanceOf(address(this));
        uint256 targetFromWrap = adapter.wrapUnderlying(wrapAmt);
        assertEq(targetFromWrap, target.balanceOf(address(this)));
        assertGt(targetFromWrap, 0);
        adapter.unwrapTarget(targetFromWrap);
        uint256 postbal = underlying.balanceOf(address(this));
        assertApproxEqAbs(prebal, postbal);
        underlying.approve(address(target), INITIAL_BALANCE / 2);
        target.deposit(INITIAL_BALANCE / 4, address(this));
        assertEq(target.totalSupply(), INITIAL_BALANCE / 4);
        assertEq(target.totalAssets(), INITIAL_BALANCE / 4);
        target.deposit(INITIAL_BALANCE / 4, address(this));
        assertEq(target.totalSupply(), INITIAL_BALANCE / 2);
        assertEq(target.totalAssets(), INITIAL_BALANCE / 2);
        uint256 targetBalPostDeposit = target.balanceOf(address(this));
        wrapAmt = bound(wrapAmt, 1, INITIAL_BALANCE / 2);
        prebal = underlying.balanceOf(address(this));
        targetFromWrap = adapter.wrapUnderlying(wrapAmt);
        assertEq(targetFromWrap + targetBalPostDeposit, target.balanceOf(address(this)));
        assertGt(targetFromWrap + targetBalPostDeposit, 0);
        adapter.unwrapTarget(targetFromWrap);
        postbal = underlying.balanceOf(address(this));
        assertEq(prebal, postbal);
    }
    function testMainnetScale() public {
        underlying.approve(address(target), INITIAL_BALANCE);
        target.deposit(INITIAL_BALANCE, address(this));
        uint256 denormalisedScale = adapter.scale() / 10**(18 - decimals);
        assertApproxEqAbs(denormalisedScale, 10**decimals);
        address eToken = EulerERC4626Like(address(target)).eToken();
        vm.startPrank(address(target));
        uint256 uBal = 2 * 10**decimals;
        deal(address(underlying), address(target), uBal); 
        address euler = EulerERC4626Like(address(target)).euler();
        underlying.approve(euler, uBal); 
        IEulerTokenLike(eToken).deposit(0, uBal);
        vm.stopPrank();
        assertGt(adapter.scale(), 1e18);
        denormalisedScale = adapter.scale() / 10**(18 - decimals);
        assertApproxEqAbs(denormalisedScale, ((INITIAL_BALANCE + 2 * 10**decimals) * 10**decimals) / INITIAL_BALANCE);
    }
    function testMainnetScaleAndScaleStored() public {
        underlying.approve(address(target), INITIAL_BALANCE);
        target.deposit(INITIAL_BALANCE, address(this));
        uint256 denormalisedScale = adapter.scale() / 10**(18 - decimals);
        uint256 denormalisedScaleStored = adapter.scaleStored() / 10**(18 - decimals);
        assertApproxEqAbs(denormalisedScale, 10**decimals);
        assertApproxEqAbs(denormalisedScaleStored, 10**decimals);
        address eToken = EulerERC4626Like(address(target)).eToken();
        vm.startPrank(address(target));
        uint256 uBal = 2 * 10**decimals;
        deal(address(underlying), address(target), uBal); 
        address euler = EulerERC4626Like(address(target)).euler();
        underlying.approve(euler, uBal); 
        IEulerTokenLike(eToken).deposit(0, uBal);
        vm.stopPrank();
        assertGt(adapter.scale(), 1e18);
        assertGt(adapter.scaleStored(), 1e18);
        denormalisedScale = adapter.scale() / 10**(18 - decimals);
        denormalisedScaleStored = adapter.scaleStored() / 10**(18 - decimals);
        uint256 expectedDenormalisedScale = ((INITIAL_BALANCE + 2 * 10**decimals) * 10**decimals) / INITIAL_BALANCE;
        assertApproxEqAbs(denormalisedScale, expectedDenormalisedScale);
        assertApproxEqAbs(denormalisedScaleStored, expectedDenormalisedScale);
    }
    function testMainnetScaleIsExRate() public {
        underlying.approve(address(target), INITIAL_BALANCE / 2);
        target.deposit(INITIAL_BALANCE / 2, address(this));
        address eToken = EulerERC4626Like(address(target)).eToken();
        vm.startPrank(address(target));
        uint256 uBal = 2 * 10**decimals;
        deal(address(underlying), address(target), uBal); 
        address euler = EulerERC4626Like(address(target)).euler();
        underlying.approve(euler, uBal); 
        IEulerTokenLike(eToken).deposit(0, uBal);
        vm.stopPrank();
        uint256 targetBalPre = target.balanceOf(address(this));
        assertGt(targetBalPre, 0);
        target.approve(address(adapter), type(uint256).max);
        underlying.approve(address(adapter), type(uint256).max);
        uint256 underlyingFromUnwrap = adapter.unwrapTarget(targetBalPre / 2);
        assertApproxEqAbs(((targetBalPre / 2) * adapter.scale()) / 1e18, underlyingFromUnwrap);
        uint256 underlyingBalPre = underlying.balanceOf(address(this));
        uint256 targetFromWrap = adapter.wrapUnderlying(underlyingBalPre / 2);
        assertApproxEqAbs(((underlyingBalPre / 2) * 1e18) / adapter.scale(), targetFromWrap);
    }
    function assertApproxEqAbs(uint256 a, uint256 b) public {
        assertApproxEqAbs(a, b, 100);
    }
}