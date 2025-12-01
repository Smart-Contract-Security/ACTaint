pragma solidity 0.8.13;
import "forge-std/Test.sol";
import { ERC4626Adapter } from "../../adapters/abstract/erc4626/ERC4626Adapter.sol";
import { ERC4626CropsAdapter } from "../../adapters/abstract/erc4626/ERC4626CropsAdapter.sol";
import { ERC4626Factory } from "../../adapters/abstract/factories/ERC4626Factory.sol";
import { ERC4626CropsFactory } from "../../adapters/abstract/factories/ERC4626CropsFactory.sol";
import { ChainlinkPriceOracle } from "../../adapters/implementations/oracles/ChainlinkPriceOracle.sol";
import { MasterPriceOracle } from "../../adapters/implementations/oracles/MasterPriceOracle.sol";
import { BaseFactory, ChainlinkOracleLike } from "../../adapters/abstract/factories/BaseFactory.sol";
import { Divider, TokenHandler } from "../../Divider.sol";
import { FixedMath } from "../../external/FixedMath.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { DateTimeFull } from "../test-helpers/DateTimeFull.sol";
import { AddressBook } from "../test-helpers/AddressBook.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Constants } from "../test-helpers/Constants.sol";
contract ERC4626TestHelper is Test {
    uint256 public mainnetFork;
    ERC4626Factory internal factory;
    ERC4626CropsFactory internal cropsFactory;
    Divider internal divider;
    TokenHandler internal tokenHandler;
    MasterPriceOracle internal masterOracle;
    uint8 public constant MODE = 0;
    uint64 public constant ISSUANCE_FEE = 0.01e18;
    uint256 public constant STAKE_SIZE = 1e18;
    uint256 public constant MIN_MATURITY = 2 weeks;
    uint256 public constant MAX_MATURITY = 14 weeks;
    uint256 public constant DEFAULT_GUARD = 100000 * 1e18;
    function setUp() public {
        tokenHandler = new TokenHandler();
        divider = new Divider(address(this), address(tokenHandler));
        tokenHandler.init(address(divider));
        ChainlinkPriceOracle chainlinkOracle = new ChainlinkPriceOracle(0);
        address[] memory underlyings = new address[](1);
        underlyings[0] = AddressBook.MUSD;
        address[] memory oracles = new address[](1);
        oracles[0] = AddressBook.RARI_MSTABLE_ORACLE;
        masterOracle = new MasterPriceOracle(address(chainlinkOracle), underlyings, oracles);
        assertEq(masterOracle.oracles(AddressBook.MUSD), AddressBook.RARI_MSTABLE_ORACLE);
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: AddressBook.WETH,
            oracle: address(masterOracle),
            ifee: ISSUANCE_FEE,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            guard: DEFAULT_GUARD
        });
        factory = new ERC4626Factory(
            address(divider),
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT,
            factoryParams
        );
        divider.setIsTrusted(address(factory), true); 
        factory.supportTarget(AddressBook.IMUSD, true);
        cropsFactory = new ERC4626CropsFactory(
            address(divider),
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT,
            factoryParams
        );
        divider.setIsTrusted(address(cropsFactory), true); 
        cropsFactory.supportTarget(AddressBook.IMUSD, true);
    }
}
contract ERC4626Factories is ERC4626TestHelper {
    using FixedMath for uint256;
    function testMainnetDeployFactory() public {
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: AddressBook.DAI,
            oracle: address(masterOracle),
            ifee: ISSUANCE_FEE,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            guard: DEFAULT_GUARD
        });
        ERC4626Factory otherFactory = new ERC4626Factory(
            address(divider),
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT,
            factoryParams
        );
        assertTrue(address(otherFactory) != address(0));
        (
            address oracle,
            address stake,
            uint256 stakeSize,
            uint256 minm,
            uint256 maxm,
            uint256 ifee,
            uint16 mode,
            uint64 tilt,
            uint256 guard
        ) = ERC4626Factory(otherFactory).factoryParams();
        assertEq(ERC4626Factory(otherFactory).divider(), address(divider));
        assertEq(stake, AddressBook.DAI);
        assertEq(ifee, ISSUANCE_FEE);
        assertEq(stakeSize, STAKE_SIZE);
        assertEq(minm, MIN_MATURITY);
        assertEq(maxm, MAX_MATURITY);
        assertEq(mode, MODE);
        assertEq(oracle, address(masterOracle));
        assertEq(tilt, 0);
        assertEq(guard, DEFAULT_GUARD);
    }
    function testMainnetDeployAdapter() public {
        vm.prank(divider.periphery());
        ERC4626Adapter adapter = ERC4626Adapter(factory.deployAdapter(AddressBook.IMUSD, ""));
        assertTrue(address(adapter) != address(0));
        assertEq(adapter.target(), address(AddressBook.IMUSD));
        assertEq(adapter.divider(), address(divider));
        assertEq(adapter.name(), "Interest bearing mUSD Adapter");
        assertEq(adapter.symbol(), "imUSD-adapter");
        uint256 scale = adapter.scale();
        assertTrue(scale > 0);
        (, , uint256 guard, ) = divider.adapterMeta(address(adapter));
        uint256 tDecimals = ERC20(adapter.target()).decimals();
        uint256 underlyingPriceInEth = adapter.getUnderlyingPrice();
        (, int256 ethPrice, , , ) = ChainlinkOracleLike(AddressBook.ETH_USD_PRICEFEED).latestRoundData();
        uint256 price = underlyingPriceInEth.fmul(uint256(ethPrice), 1e8);
        price = scale.fmul(price, 10**tDecimals);
        uint256 guardInTarget = DEFAULT_GUARD.fdiv(price, 10**tDecimals);
        assertApproxEqAbs(guard, guardInTarget, guard.fmul(0.010e18));
    }
    function testMainnetDeployCropsAdapter() public {
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = AddressBook.DAI;
        rewardTokens[1] = AddressBook.WETH;
        bytes memory data = abi.encode(rewardTokens);
        vm.prank(divider.periphery());
        ERC4626CropsAdapter adapter = ERC4626CropsAdapter(cropsFactory.deployAdapter(AddressBook.IMUSD, data));
        assertTrue(address(adapter) != address(0));
        assertEq(adapter.target(), address(AddressBook.IMUSD));
        assertEq(adapter.divider(), address(divider));
        assertEq(adapter.name(), "Interest bearing mUSD Adapter");
        assertEq(adapter.symbol(), "imUSD-adapter");
        assertEq(adapter.rewardTokens(0), AddressBook.DAI);
        assertEq(adapter.rewardTokens(1), AddressBook.WETH);
        uint256 scale = adapter.scale();
        assertTrue(scale > 0);
        (, , uint256 guard, ) = divider.adapterMeta(address(adapter));
        assertApproxEqAbs(guard, (100000 * 1e36) / scale, guard.fmul(0.010e18));
    }
    function testMainnetCantDeployAdapterIfNotSupportedTarget() public {
        address[] memory rewardTokens;
        bytes memory data = abi.encode(rewardTokens);
        divider.setPeriphery(address(this));
        vm.expectRevert(abi.encodeWithSelector(Errors.TargetNotSupported.selector));
        factory.deployAdapter(AddressBook.DAI, data);
    }
    function testMainnetCanDeployAdapterIfNotSupportedTargetButPermissionless() public {
        factory.supportTarget(AddressBook.IMUSD, false);
        Divider(factory.divider()).setPermissionless(true);
        address[] memory rewardTokens;
        bytes memory data = abi.encode(rewardTokens);
        vm.prank(divider.periphery());
        factory.deployAdapter(AddressBook.IMUSD, data);
    }
    function testMainnetCanSupportTarget() public {
        assertTrue(!factory.supportedTargets(AddressBook.cDAI));
        factory.supportTarget(AddressBook.cDAI, true);
        assertTrue(factory.supportedTargets(AddressBook.cDAI));
    }
    function testMainnetCantSupportTargetIfNotTrusted() public {
        assertTrue(!factory.supportedTargets(AddressBook.cDAI));
        vm.prank(address(1));
        vm.expectRevert("UNTRUSTED");
        factory.supportTarget(AddressBook.cDAI, true);
    }
}