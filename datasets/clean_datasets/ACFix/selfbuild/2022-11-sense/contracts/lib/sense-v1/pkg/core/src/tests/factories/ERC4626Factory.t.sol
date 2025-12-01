pragma solidity 0.8.13;
import { ERC4626Factory } from "../../adapters/abstract/factories/ERC4626Factory.sol";
import { ERC4626CropsFactory } from "../../adapters/abstract/factories/ERC4626CropsFactory.sol";
import { ERC4626CropFactory } from "../../adapters/abstract/factories/ERC4626CropFactory.sol";
import { ERC4626CropsAdapter } from "../../adapters/abstract/erc4626/ERC4626CropsAdapter.sol";
import { ERC4626CropAdapter } from "../../adapters/abstract/erc4626/ERC4626CropAdapter.sol";
import { MasterPriceOracle } from "../../adapters/implementations/oracles/MasterPriceOracle.sol";
import { TestHelper, MockTargetLike } from "../test-helpers/TestHelper.sol";
import { MockAdapter } from "../test-helpers/mocks/MockAdapter.sol";
import { MockToken } from "../test-helpers/mocks/MockToken.sol";
import { MockERC4626 } from "../test-helpers/mocks/MockERC4626.sol";
import { MockTarget } from "../test-helpers/mocks/MockTarget.sol";
import { DateTimeFull } from "../test-helpers/DateTimeFull.sol";
import { BaseAdapter } from "../../adapters/abstract/BaseAdapter.sol";
import { BaseFactory } from "../../adapters/abstract/factories/BaseFactory.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Constants } from "../test-helpers/Constants.sol";
contract ERC4626FactoryTest is TestHelper {
    function setUp() public override {
        super.setUp();
        is4626Target = true;
    }
    function testDeployFactory() public {
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: address(stake),
            oracle: ORACLE,
            ifee: ISSUANCE_FEE,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            guard: 123e18
        });
        ERC4626Factory someFactory = new ERC4626Factory(
            address(divider),
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT,
            factoryParams
        );
        assertTrue(address(someFactory) != address(0));
        assertEq(ERC4626Factory(someFactory).divider(), address(divider));
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
        ) = ERC4626Factory(someFactory).factoryParams();
        assertEq(oracle, ORACLE);
        assertEq(stake, address(stake));
        assertEq(ifee, ISSUANCE_FEE);
        assertEq(stakeSize, STAKE_SIZE);
        assertEq(minm, MIN_MATURITY);
        assertEq(maxm, MAX_MATURITY);
        assertEq(mode, MODE);
        assertEq(tilt, 0);
        assertEq(guard, 123e18);
    }
    function testDeployNonCropAdapter() public {
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626Factory someFactory = ERC4626Factory(deployFactory(address(someTarget)));
        vm.prank(address(periphery));
        address adapter = someFactory.deployAdapter(address(someTarget), "");
        assertTrue(adapter != address(0));
        (address oracle, address stake, uint256 stakeSize, uint256 minm, uint256 maxm, , , ) = MockAdapter(adapter)
            .adapterParams();
        assertEq(MockAdapter(adapter).divider(), address(divider));
        assertEq(MockAdapter(adapter).target(), address(someTarget));
        assertEq(MockAdapter(adapter).name(), "Some Target Adapter");
        assertEq(MockAdapter(adapter).symbol(), "ST-adapter");
        assertEq(MockAdapter(adapter).ifee(), ISSUANCE_FEE);
        assertEq(oracle, ORACLE);
        assertEq(stake, address(stake));
        assertEq(stakeSize, STAKE_SIZE);
        assertEq(minm, MIN_MATURITY);
        assertEq(maxm, MAX_MATURITY);
        assertEq(MockAdapter(adapter).mode(), MODE);
        uint256 scale = MockAdapter(adapter).scale();
        assertEq(scale, 1e18);
    }
    function testDeployCropAdapter() public {
        MockToken someReward = new MockToken("Some Reward", "SR", 18);
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626CropFactory someFactory = ERC4626CropFactory(deployCropFactory(address(someTarget)));
        bytes memory data = abi.encode(address(someReward));
        vm.prank(address(periphery));
        ERC4626CropAdapter adapter = ERC4626CropAdapter(someFactory.deployAdapter(address(someTarget), data));
        assertTrue(address(adapter) != address(0));
        (address oracle, address stake, uint256 stakeSize, uint256 minm, uint256 maxm, , , ) = adapter.adapterParams();
        assertEq(adapter.divider(), address(divider));
        assertEq(adapter.rewardsRecipient(), Constants.REWARDS_RECIPIENT);
        assertEq(adapter.target(), address(someTarget));
        assertEq(adapter.name(), "Some Target Adapter");
        assertEq(adapter.symbol(), "ST-adapter");
        assertEq(adapter.ifee(), ISSUANCE_FEE);
        assertEq(oracle, ORACLE);
        assertEq(stake, address(stake));
        assertEq(stakeSize, STAKE_SIZE);
        assertEq(minm, MIN_MATURITY);
        assertEq(maxm, MAX_MATURITY);
        assertEq(adapter.mode(), MODE);
        assertEq(adapter.reward(), address(someReward));
        uint256 scale = adapter.scale();
        assertEq(scale, 1e18);
    }
    function testDeployCropsAdapter() public {
        MockToken someReward = new MockToken("Some Reward", "SR", 18);
        MockToken someReward2 = new MockToken("Some Reward 2", "SR2", 18);
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626CropsFactory someFactory = ERC4626CropsFactory(deployCropsFactory(address(someTarget)));
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(someReward);
        rewardTokens[1] = address(someReward2);
        bytes memory data = abi.encode(rewardTokens);
        vm.prank(address(periphery));
        ERC4626CropsAdapter adapter = ERC4626CropsAdapter(someFactory.deployAdapter(address(someTarget), data));
        assertTrue(address(adapter) != address(0));
        (address oracle, address stake, uint256 stakeSize, uint256 minm, uint256 maxm, , , ) = adapter.adapterParams();
        assertEq(adapter.divider(), address(divider));
        assertEq(adapter.rewardsRecipient(), Constants.REWARDS_RECIPIENT);
        assertEq(adapter.target(), address(someTarget));
        assertEq(adapter.name(), "Some Target Adapter");
        assertEq(adapter.symbol(), "ST-adapter");
        assertEq(adapter.ifee(), ISSUANCE_FEE);
        assertEq(oracle, ORACLE);
        assertEq(stake, address(stake));
        assertEq(stakeSize, STAKE_SIZE);
        assertEq(minm, MIN_MATURITY);
        assertEq(maxm, MAX_MATURITY);
        assertEq(adapter.mode(), MODE);
        assertEq(adapter.rewardTokens(0), address(someReward));
        assertEq(adapter.rewardTokens(1), address(someReward2));
        uint256 scale = adapter.scale();
        assertEq(scale, 1e18);
    }
    function testDeployAdapterAndInitializeSeries() public {
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626Factory someFactory = ERC4626Factory(deployFactory(address(someTarget)));
        address[] memory rewardTokens;
        bytes memory data = abi.encode(rewardTokens);
        address adapter = periphery.deployAdapter(address(someFactory), address(someTarget), data);
        assertTrue(adapter != address(0));
        uint256 scale = MockAdapter(adapter).scale();
        assertEq(scale, 1e18);
        vm.warp(block.timestamp + 1 days);
        uint256 maturity = DateTimeFull.timestampFromDateTime(2021, 10, 1, 0, 0, 0);
        (address principal, address yield) = periphery.sponsorSeries(adapter, maturity, true);
        assertTrue(principal != address(0));
        assertTrue(yield != address(0));
    }
    function testCantDeployAdapterIfNotPeriphery() public {
        MockToken someUnderlying = new MockToken("Some Underlying", "SU", 18);
        MockTargetLike someTarget = MockTargetLike(
            deployMockTarget(address(someUnderlying), "Some Target", "ST", tDecimals)
        );
        factory.supportTarget(address(someTarget), true);
        MasterPriceOracle oracle = MasterPriceOracle(ORACLE);
        bytes memory data = abi.encode(1e18); 
        vm.mockCall(address(ORACLE), abi.encodeWithSelector(oracle.price.selector, address(underlying)), data);
        address[] memory rewardTokens = new address[](0);
        vm.expectRevert(abi.encodeWithSelector(Errors.OnlyPeriphery.selector));
        factory.deployAdapter(address(someTarget), abi.encode(rewardTokens));
    }
    function testCanSupportTarget() public {
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626Factory someFactory = ERC4626Factory(deployFactory(address(someTarget)));
        address target = address(0xbabe);
        vm.expectEmit(true, true, false, true);
        emit TargetSupported(target, true);
        assertTrue(!someFactory.supportedTargets(target));
        someFactory.supportTarget(target, true);
        assertTrue(someFactory.supportedTargets(target));
    }
    function testCantSupportTargetIfNotAdmin() public {
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626Factory someFactory = ERC4626Factory(deployFactory(address(someTarget)));
        vm.expectRevert("UNTRUSTED");
        vm.prank(address(0x4b1d));
        someFactory.supportTarget(address(0xbabe), true);
    }
    function testFailDeployAdapterIfAlreadyExists() public {
        vm.prank(address(periphery));
        factory.deployAdapter(address(target), abi.encode(address(reward)));
    }
    function testCanSetRewardToken() public {
        MockToken someReward = new MockToken("Some Reward", "SR", 18);
        MockERC4626 someTarget = new MockERC4626(underlying, "Some Target", "ST", MockToken(underlying).decimals());
        ERC4626CropFactory someFactory = ERC4626CropFactory(deployCropFactory(address(someTarget)));
        bytes memory data = abi.encode(address(0)); 
        vm.prank(address(periphery));
        ERC4626CropAdapter adapter = ERC4626CropAdapter(someFactory.deployAdapter(address(someTarget), data));
        assertTrue(address(adapter) != address(0));
        vm.expectRevert("UNTRUSTED");
        adapter.setRewardToken(address(0x111));
        vm.prank(Constants.RESTRICTED_ADMIN);
        adapter.setRewardToken(address(0x111));
        assertEq(adapter.reward(), address(0x111));
    }
    event TargetSupported(address indexed target, bool indexed supported);
}