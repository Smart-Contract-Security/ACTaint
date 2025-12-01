pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { FixedMath } from "../../external/FixedMath.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Divider, TokenHandler } from "../../Divider.sol";
import { CAdapter, CTokenLike, PriceOracleLike } from "../../adapters/implementations/compound/CAdapter.sol";
import { BaseAdapter } from "../../adapters/abstract/BaseAdapter.sol";
import { AddressBook } from "../test-helpers/AddressBook.sol";
import { DateTimeFull } from "../test-helpers/DateTimeFull.sol";
import { Constants } from "../test-helpers/Constants.sol";
interface ComptrollerLike {
    function updateContributorRewards(address contributor) external;
    function compContributorSpeeds(address contributor) external view returns (uint256);
    function _setContributorCompSpeed(address contributor, uint256 compSpeed) external;
    function admin() external view returns (address);
    function compAccrued(address usr) external view returns (uint256);
}
contract CAdapterTestHelper is Test {
    using SafeTransferLib for ERC20;
    CAdapter internal cDaiAdapter;
    CAdapter internal cEthAdapter;
    CAdapter internal cUsdcAdapter;
    Divider internal divider;
    TokenHandler internal tokenHandler;
    uint256 public constant ONE_CTOKEN = 1e8;
    uint16 public constant DEFAULT_LEVEL = 31;
    uint8 public constant MODE = 0;
    uint64 public constant ISSUANCE_FEE = 0.01e18;
    uint256 public constant STAKE_SIZE = 1e18;
    uint256 public constant MIN_MATURITY = 2 weeks;
    uint256 public constant MAX_MATURITY = 14 weeks;
    function setUp() public {
        deal(AddressBook.DAI, address(this), 20e18);
        deal(AddressBook.WETH, address(this), 20e18);
        mintCToken(AddressBook.cDAI, 10e18);
        mintCToken(AddressBook.cETH, 10e18);
        tokenHandler = new TokenHandler();
        divider = new Divider(address(this), address(tokenHandler));
        divider.setPeriphery(address(this));
        tokenHandler.init(address(divider));
        address target = AddressBook.cDAI;
        address underlying = CTokenLike(AddressBook.cDAI).underlying();
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: AddressBook.RARI_ORACLE,
            stake: AddressBook.DAI,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: 0,
            tilt: 0,
            level: DEFAULT_LEVEL
        });
        cDaiAdapter = new CAdapter(
            address(divider),
            target,
            underlying,
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            adapterParams,
            AddressBook.COMP
        ); 
        target = AddressBook.cUSDC;
        underlying = CTokenLike(AddressBook.cUSDC).underlying();
        cUsdcAdapter = new CAdapter(
            address(divider),
            target,
            underlying,
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            adapterParams,
            AddressBook.COMP
        ); 
        target = AddressBook.cETH;
        underlying = AddressBook.WETH;
        adapterParams.minm = 0;
        cEthAdapter = new CAdapter(
            address(divider),
            target,
            underlying,
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            adapterParams,
            AddressBook.COMP
        ); 
    }
    function mintCToken(address cToken, uint256 mintAmount) internal {
        if (cToken == AddressBook.cETH) {
            AddressBook.cETH.call{ value: mintAmount }("");
        } else {
            ERC20 underlying = ERC20(CTokenLike(cToken).underlying());
            underlying.safeApprove(cToken, mintAmount);
            CTokenLike(AddressBook.cDAI).mint(mintAmount);
        }
    }
}
contract CAdapters is CAdapterTestHelper {
    using FixedMath for uint256;
    function testMainnetCAdapterScale() public {
        CTokenLike underlying = CTokenLike(AddressBook.DAI);
        CTokenLike ctoken = CTokenLike(AddressBook.cDAI);
        uint256 uDecimals = underlying.decimals();
        uint256 scale = ctoken.exchangeRateCurrent() / 10**(uDecimals - 8);
        assertEq(cDaiAdapter.scale(), scale);
    }
    function testMainnetGetUnderlyingPrice() public {
        PriceOracleLike oracle = PriceOracleLike(AddressBook.RARI_ORACLE);
        uint256 price = oracle.price(AddressBook.DAI);
        assertEq(cDaiAdapter.getUnderlyingPrice(), price);
    }
    function testMainnetUnwrapTarget() public {
        uint256 uBalanceBefore = ERC20(AddressBook.DAI).balanceOf(address(this));
        uint256 tBalanceBefore = ERC20(AddressBook.cDAI).balanceOf(address(this));
        ERC20(AddressBook.cDAI).approve(address(cDaiAdapter), tBalanceBefore);
        uint256 rate = CTokenLike(AddressBook.cDAI).exchangeRateCurrent();
        uint256 uDecimals = ERC20(AddressBook.DAI).decimals();
        uint256 unwrapped = tBalanceBefore.fmul(rate, 10**uDecimals);
        cDaiAdapter.unwrapTarget(tBalanceBefore);
        uint256 tBalanceAfter = ERC20(AddressBook.cDAI).balanceOf(address(this));
        uint256 uBalanceAfter = ERC20(AddressBook.DAI).balanceOf(address(this));
        assertEq(tBalanceAfter, 0);
        assertEq(uBalanceBefore + unwrapped, uBalanceAfter);
    }
    function testMainnetWrapUnderlying() public {
        uint256 uBalanceBefore = ERC20(AddressBook.DAI).balanceOf(address(this));
        uint256 tBalanceBefore = ERC20(AddressBook.cDAI).balanceOf(address(this));
        ERC20(AddressBook.DAI).approve(address(cDaiAdapter), uBalanceBefore);
        uint256 rate = CTokenLike(AddressBook.cDAI).exchangeRateCurrent();
        uint256 uDecimals = ERC20(AddressBook.DAI).decimals();
        uint256 wrapped = uBalanceBefore.fdiv(rate, 10**uDecimals);
        cDaiAdapter.wrapUnderlying(uBalanceBefore);
        uint256 tBalanceAfter = ERC20(AddressBook.cDAI).balanceOf(address(this));
        uint256 uBalanceAfter = ERC20(AddressBook.DAI).balanceOf(address(this));
        assertEq(uBalanceAfter, 0);
        assertEq(tBalanceBefore + wrapped, tBalanceAfter);
    }
    function testMainnetCETHAdapterScale() public {
        CTokenLike underlying = CTokenLike(AddressBook.WETH);
        CTokenLike ctoken = CTokenLike(AddressBook.cETH);
        uint256 uDecimals = underlying.decimals();
        uint256 scale = ctoken.exchangeRateCurrent() / 10**(uDecimals - 8);
        assertEq(cEthAdapter.scale(), scale);
    }
    function testMainnetCETHGetUnderlyingPrice() public {
        assertEq(cEthAdapter.getUnderlyingPrice(), 1e18);
    }
    function testMainnetCETHUnwrapTarget() public {
        uint256 uBalanceBefore = ERC20(AddressBook.WETH).balanceOf(address(this));
        uint256 tBalanceBefore = ERC20(AddressBook.cETH).balanceOf(address(this));
        ERC20(AddressBook.cETH).approve(address(cEthAdapter), tBalanceBefore);
        uint256 rate = CTokenLike(AddressBook.cETH).exchangeRateCurrent();
        uint256 uDecimals = ERC20(AddressBook.WETH).decimals();
        uint256 unwrapped = tBalanceBefore.fmul(rate, 10**uDecimals);
        cEthAdapter.unwrapTarget(tBalanceBefore);
        uint256 tBalanceAfter = ERC20(AddressBook.cETH).balanceOf(address(this));
        uint256 uBalanceAfter = ERC20(AddressBook.WETH).balanceOf(address(this));
        assertEq(tBalanceAfter, 0);
        assertEq(uBalanceBefore + unwrapped, uBalanceAfter);
    }
    function testMainnetCETHWrapUnderlying() public {
        uint256 uBalanceBefore = ERC20(AddressBook.WETH).balanceOf(address(this));
        uint256 tBalanceBefore = ERC20(AddressBook.cETH).balanceOf(address(this));
        ERC20(AddressBook.WETH).approve(address(cEthAdapter), uBalanceBefore);
        uint256 rate = CTokenLike(AddressBook.cETH).exchangeRateCurrent();
        uint256 uDecimals = ERC20(AddressBook.WETH).decimals();
        uint256 wrapped = uBalanceBefore.fdiv(rate, 10**uDecimals);
        cEthAdapter.wrapUnderlying(uBalanceBefore);
        uint256 tBalanceAfter = ERC20(AddressBook.cETH).balanceOf(address(this));
        uint256 uBalanceAfter = ERC20(AddressBook.WETH).balanceOf(address(this));
        assertEq(uBalanceAfter, 0);
        assertEq(tBalanceBefore + wrapped, tBalanceAfter);
    }
    event DistributedBorrowerComp(
        address indexed cToken,
        address indexed borrower,
        uint256 compDelta,
        uint256 compBorrowIndex
    );
    event DistributedSupplierComp(
        address indexed cToken,
        address indexed supplier,
        uint256 compDelta,
        uint256 compSupplyIndex
    );
    function testMainnetNotifyCAdapter() public {
        divider.addAdapter(address(cEthAdapter));
        divider.setGuard(address(cEthAdapter), 100e18);
        (uint256 year, uint256 month, ) = DateTimeFull.timestampToDate(block.timestamp);
        uint256 maturity = DateTimeFull.timestampFromDateTime(
            month == 12 ? year + 1 : year,
            month == 12 ? 1 : (month + 1),
            1,
            0,
            0,
            0
        );
        deal(AddressBook.DAI, address(this), 1e18);
        ERC20(AddressBook.DAI).approve(address(divider), type(uint256).max);
        divider.initSeries(address(cEthAdapter), maturity, address(this));
        address target = cEthAdapter.target();
        deal(target, address(this), 1e18);
        ERC20(target).approve(address(divider), type(uint256).max);
        divider.issue(address(cEthAdapter), maturity, 1e18);
        vm.prank(ComptrollerLike(AddressBook.COMPTROLLER).admin());
        ComptrollerLike(AddressBook.COMPTROLLER)._setContributorCompSpeed(address(cEthAdapter), 1e18);
        vm.roll(block.number + 10);
        ComptrollerLike(AddressBook.COMPTROLLER).updateContributorRewards(address(cEthAdapter));
        vm.expectEmit(true, true, false, false);
        emit DistributedBorrowerComp(address(target), address(cEthAdapter), 0, 0);
        vm.expectEmit(true, true, false, false);
        emit DistributedSupplierComp(address(target), address(cEthAdapter), 0, 0);
        vm.prank(address(divider));
        cEthAdapter.notify(address(0), 0, true);
        vm.roll(block.number + 10);
        vm.expectEmit(true, true, false, false);
        emit DistributedBorrowerComp(address(target), address(cEthAdapter), 0, 0);
        vm.expectEmit(true, true, false, false);
        emit DistributedSupplierComp(address(target), address(cEthAdapter), 0, 0);
        vm.prank(address(divider));
        cEthAdapter.notify(address(0), 0, true);
    }
    function testFailMainnetSkipClaimRewardIfAlreadyCalled() public {
        vm.startPrank(address(divider));
        address target = cEthAdapter.target();
        vm.expectEmit(true, true, false, false);
        emit DistributedBorrowerComp(address(target), address(cEthAdapter), 0, 0);
        vm.expectEmit(true, true, false, false);
        emit DistributedSupplierComp(address(target), address(cEthAdapter), 0, 0);
        cEthAdapter.notify(address(0), 0, true);
        vm.expectEmit(true, true, false, false);
        emit DistributedBorrowerComp(address(target), address(cEthAdapter), 0, 0);
        vm.expectEmit(true, true, false, false);
        emit DistributedSupplierComp(address(target), address(cEthAdapter), 0, 0);
        cEthAdapter.notify(address(0), 0, true);
    }
    function testMainnet18Decimals() public {
        deal(AddressBook.cETH, address(this), ONE_CTOKEN);
        ERC20(AddressBook.cETH).approve(address(cEthAdapter), ONE_CTOKEN);
        uint256 wethOut = cEthAdapter.unwrapTarget(ONE_CTOKEN);
        assertEq(cEthAdapter.scale(), wethOut);
        assertEq(ERC20(AddressBook.WETH).decimals(), 18);
        deal(AddressBook.cUSDC, address(this), ONE_CTOKEN);
        ERC20(AddressBook.cUSDC).approve(address(cUsdcAdapter), ONE_CTOKEN);
        uint256 usdcOut = cUsdcAdapter.unwrapTarget(ONE_CTOKEN);
        assertEq((cUsdcAdapter.scale() / 1e12) * 1e12, usdcOut * 10**(18 - 6));
        assertEq(ERC20(AddressBook.USDC).decimals(), 6);
    }
}