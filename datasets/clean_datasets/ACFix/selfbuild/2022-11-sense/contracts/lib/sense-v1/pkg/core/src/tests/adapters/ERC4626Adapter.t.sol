pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC4626 } from "../test-helpers/mocks/MockERC4626.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { ChainlinkPriceOracle, FeedRegistryLike } from "../../adapters/implementations/oracles/ChainlinkPriceOracle.sol";
import { MasterPriceOracle } from "../../adapters/implementations/oracles/MasterPriceOracle.sol";
import { IPriceFeed } from "../../adapters/abstract/IPriceFeed.sol";
import { BaseAdapter } from "../../adapters/abstract/BaseAdapter.sol";
import { ERC4626Adapter } from "../../adapters/abstract/erc4626/ERC4626Adapter.sol";
import { Divider, TokenHandler } from "../../Divider.sol";
import { AddressBook } from "../test-helpers/AddressBook.sol";
import { MockToken } from "../test-helpers/mocks/MockToken.sol";
import { Constants } from "../test-helpers/Constants.sol";
import { FixedMath } from "../../external/FixedMath.sol";
contract MockOracle is IPriceFeed {
    function price(address) external view returns (uint256 price) {
        return 555e18;
    }
}
contract ERC4626AdapterTest is Test {
    using FixedMath for uint256;
    MockToken public stake;
    MockToken public underlying;
    MockERC4626 public target;
    MasterPriceOracle public masterOracle;
    ChainlinkPriceOracle public chainlinkOracle;
    Divider public divider;
    ERC4626Adapter public erc4626Adapter;
    uint64 public constant ISSUANCE_FEE = 0.01e18;
    uint256 public constant STAKE_SIZE = 1e18;
    uint256 public constant MIN_MATURITY = 2 weeks;
    uint256 public constant MAX_MATURITY = 14 weeks;
    uint8 public constant MODE = 0;
    uint256 public constant INITIAL_BALANCE = 1.25e18;
    function setUp() public {
        TokenHandler tokenHandler = new TokenHandler();
        divider = new Divider(address(this), address(tokenHandler));
        divider.setPeriphery(address(this));
        tokenHandler.init(address(divider));
        chainlinkOracle = new ChainlinkPriceOracle(0);
        address[] memory data;
        masterOracle = new MasterPriceOracle(address(chainlinkOracle), data, data);
        stake = new MockToken("Mock Stake", "MS", 18);
        underlying = new MockToken("Mock Underlying", "MU", 18);
        target = new MockERC4626(ERC20(address(underlying)), "Mock ERC-4626", "M4626", ERC20(underlying).decimals());
        underlying.mint(address(this), INITIAL_BALANCE);
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: address(masterOracle),
            stake: address(stake),
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            level: Constants.DEFAULT_LEVEL
        });
        erc4626Adapter = new ERC4626Adapter(
            address(divider),
            address(target),
            Constants.REWARDS_RECIPIENT,
            ISSUANCE_FEE,
            adapterParams
        );
    }
    function testWrapUnwrap(uint256 wrapAmt) public {
        wrapAmt = bound(wrapAmt, 1, INITIAL_BALANCE);
        target.approve(address(erc4626Adapter), type(uint256).max);
        underlying.approve(address(erc4626Adapter), type(uint256).max);
        uint256 prebal = underlying.balanceOf(address(this));
        uint256 targetFromWrap = erc4626Adapter.wrapUnderlying(wrapAmt);
        assertEq(targetFromWrap, target.balanceOf(address(this)));
        assertGt(targetFromWrap, 0);
        erc4626Adapter.unwrapTarget(targetFromWrap);
        uint256 postbal = underlying.balanceOf(address(this));
        assertEq(prebal, postbal);
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
        targetFromWrap = erc4626Adapter.wrapUnderlying(wrapAmt);
        assertEq(targetFromWrap + targetBalPostDeposit, target.balanceOf(address(this)));
        assertGt(targetFromWrap + targetBalPostDeposit, 0);
        erc4626Adapter.unwrapTarget(targetFromWrap);
        postbal = underlying.balanceOf(address(this));
        assertEq(prebal, postbal);
    }
    function testWrapUnwrapZeroAmt() public {
        uint256 wrapAmt = 0;
        target.approve(address(erc4626Adapter), type(uint256).max);
        underlying.approve(address(erc4626Adapter), type(uint256).max);
        vm.expectRevert("ZERO_SHARES");
        uint256 targetFromWrap = erc4626Adapter.wrapUnderlying(wrapAmt);
        vm.expectRevert("ZERO_ASSETS");
        erc4626Adapter.unwrapTarget(targetFromWrap);
    }
    function testCantWrapMoreThanBalance() public {
        uint256 wrapAmt = INITIAL_BALANCE + 1;
        target.approve(address(erc4626Adapter), type(uint256).max);
        underlying.approve(address(erc4626Adapter), type(uint256).max);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        erc4626Adapter.wrapUnderlying(wrapAmt);
    }
    function testCantUnwrapMoreThanBalance(uint256 wrapAmt) public {
        wrapAmt = bound(wrapAmt, 1, INITIAL_BALANCE);
        target.approve(address(erc4626Adapter), type(uint256).max);
        underlying.approve(address(erc4626Adapter), type(uint256).max);
        uint256 targetFromWrap = erc4626Adapter.wrapUnderlying(wrapAmt);
        assertEq(targetFromWrap, target.balanceOf(address(this)));
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        erc4626Adapter.unwrapTarget(targetFromWrap + 1);
    }
    function testScale() public {
        underlying.approve(address(target), INITIAL_BALANCE / 2);
        target.deposit(INITIAL_BALANCE / 2, address(this));
        assertEq(erc4626Adapter.scale(), 1e18);
        underlying.mint(address(target), 2e18);
        assertGt(erc4626Adapter.scale(), 1e18);
        assertEq(erc4626Adapter.scale(), ((INITIAL_BALANCE / 2 + 2e18) * 1e18) / (INITIAL_BALANCE / 2));
    }
    function testScaleIsExRate() public {
        underlying.approve(address(target), INITIAL_BALANCE / 2);
        target.deposit(INITIAL_BALANCE / 2, address(this));
        underlying.mint(address(target), 2e18);
        target.approve(address(erc4626Adapter), type(uint256).max);
        underlying.approve(address(erc4626Adapter), type(uint256).max);
        uint256 targetBalPre = target.balanceOf(address(this));
        assertGt(targetBalPre, 0);
        uint256 underlyingFromUnwrap = erc4626Adapter.unwrapTarget(targetBalPre / 2);
        assertEq(((targetBalPre / 2) * erc4626Adapter.scale()) / 1e18, underlyingFromUnwrap);
        uint256 underlyingBalPre = underlying.balanceOf(address(this));
        uint256 targetFromWrap = erc4626Adapter.wrapUnderlying(underlyingBalPre / 2);
        assertEq(((underlyingBalPre / 2) * 1e18) / erc4626Adapter.scale(), targetFromWrap);
    }
    function testScaleAndScaleStored() public {
        underlying.approve(address(target), INITIAL_BALANCE / 2);
        target.deposit(INITIAL_BALANCE / 2, address(this));
        assertEq(erc4626Adapter.scale(), 1e18);
        assertEq(erc4626Adapter.scaleStored(), 1e18);
        underlying.mint(address(target), 2e18);
        assertGt(erc4626Adapter.scale(), 1e18);
        assertGt(erc4626Adapter.scaleStored(), 1e18);
        uint256 scale = ((INITIAL_BALANCE / 2 + 2e18) * 1e18) / (INITIAL_BALANCE / 2);
        assertEq(erc4626Adapter.scale(), scale);
        assertEq(erc4626Adapter.scaleStored(), scale);
    }
    function testGetUnderlyingPriceUsingSenseChainlinkOracle() public {
        uint256 price = 123e18;
        bytes memory data = abi.encode(price); 
        vm.mockCall(
            address(chainlinkOracle),
            abi.encodeWithSelector(chainlinkOracle.price.selector, address(underlying)),
            data
        );
        assertEq(erc4626Adapter.getUnderlyingPrice(), price);
    }
    function testGetUnderlyingPriceRevertsIfZero() public {
        uint256 price = 0;
        bytes memory data = abi.encode(price); 
        vm.mockCall(
            address(chainlinkOracle),
            abi.encodeWithSelector(chainlinkOracle.price.selector, address(underlying)),
            data
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidPrice.selector));
        erc4626Adapter.getUnderlyingPrice();
    }
    function testGetUnderlyingPriceCustomOracle() public {
        MockOracle oracle = new MockOracle();
        address[] memory underlyings = new address[](1);
        underlyings[0] = address(underlying);
        address[] memory oracles = new address[](1);
        oracles[0] = address(oracle);
        masterOracle.add(underlyings, oracles);
        uint256 price = MockOracle(oracle).price(address(underlying));
        assertEq(erc4626Adapter.getUnderlyingPrice(), price);
    }
    function testShouldAlwaysDefaultToCustom() public {
        uint256 price = 123e18;
        bytes memory data = abi.encode(price); 
        IPriceFeed oracle = IPriceFeed(AddressBook.RARI_ORACLE);
        vm.mockCall(
            address(AddressBook.RARI_ORACLE),
            abi.encodeWithSelector(oracle.price.selector, address(underlying)),
            data
        );
        MockOracle customOracle = new MockOracle();
        address[] memory underlyings = new address[](1);
        underlyings[0] = address(underlying);
        address[] memory oracles = new address[](1);
        oracles[0] = address(customOracle);
        masterOracle.add(underlyings, oracles);
        assertEq(erc4626Adapter.getUnderlyingPrice(), customOracle.price(address(underlying)));
    }
}