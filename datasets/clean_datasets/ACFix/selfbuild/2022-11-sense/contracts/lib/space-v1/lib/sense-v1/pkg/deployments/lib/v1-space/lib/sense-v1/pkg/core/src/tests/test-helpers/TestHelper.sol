pragma solidity 0.8.11;
import { GYTManager } from "../../modules/GYTManager.sol";
import { Divider, TokenHandler } from "../../Divider.sol";
import { BaseFactory } from "../../adapters/BaseFactory.sol";
import { BaseAdapter } from "../../adapters/BaseAdapter.sol";
import { PoolManager } from "@sense-finance/v1-fuse/src/PoolManager.sol";
import { Token } from "../../tokens/Token.sol";
import { Periphery } from "../../Periphery.sol";
import { MockToken } from "./mocks/MockToken.sol";
import { MockTarget } from "./mocks/MockTarget.sol";
import { MockAdapter } from "./mocks/MockAdapter.sol";
import { MockFactory, MockCropsFactory } from "./mocks/MockFactory.sol";
import { MockSpaceFactory, MockBalancerVault } from "./mocks/MockSpace.sol";
import { MockComptroller } from "./mocks/fuse/MockComptroller.sol";
import { MockFuseDirectory } from "./mocks/fuse/MockFuseDirectory.sol";
import { MockOracle } from "./mocks/fuse/MockOracle.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { DSTest } from "./test.sol";
import { Hevm } from "./Hevm.sol";
import { DateTimeFull } from "./DateTimeFull.sol";
import { User } from "./User.sol";
import { FixedMath } from "../../external/FixedMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
contract TestHelper is DSTest {
    using FixedMath for uint256;
    MockAdapter internal adapter;
    MockToken internal stake;
    MockToken internal underlying;
    MockTarget internal target;
    MockToken internal reward;
    MockFactory internal factory;
    MockOracle internal masterOracle;
    PoolManager internal poolManager;
    GYTManager internal gYTManager;
    Divider internal divider;
    TokenHandler internal tokenHandler;
    Periphery internal periphery;
    User internal alice;
    User internal bob;
    User internal jim;
    Hevm internal constant hevm = Hevm(HEVM_ADDRESS);
    MockSpaceFactory internal spaceFactory;
    MockBalancerVault internal balancerVault;
    MockComptroller internal comptroller;
    MockFuseDirectory internal fuseDirectory;
    BaseAdapter.AdapterParams public DEFAULT_ADAPTER_PARAMS;
    uint256 internal GROWTH_PER_SECOND = 792744799594; 
    uint16 public MODE = 0;
    address public ORACLE = address(123);
    uint64 public ISSUANCE_FEE = 0.05e18;
    uint256 public STAKE_SIZE = 1e18;
    uint256 public MIN_MATURITY = 2 weeks;
    uint256 public MAX_MATURITY = 14 weeks;
    uint16 public DEFAULT_LEVEL = 31;
    uint16 public DEFAULT_TILT = 0;
    uint256 public SPONSOR_WINDOW;
    uint256 public SETTLEMENT_WINDOW;
    uint256 public SCALING_FACTOR;
    uint8 internal mockUnderlyingDecimals;
    uint8 internal mockTargetDecimals;
    function setUp() public virtual {
        hevm.warp(1630454400);
        uint8 baseDecimals = 18;
        string[] memory inputs = new string[](2);
        inputs[0] = "just";
        inputs[1] = "_forge_mock_underlying_decimals";
        mockUnderlyingDecimals = uint8(abi.decode(hevm.ffi(inputs), (uint256)));
        inputs[1] = "_forge_mock_target_decimals";
        mockTargetDecimals = uint8(abi.decode(hevm.ffi(inputs), (uint256)));
        stake = new MockToken("Stake Token", "ST", baseDecimals);
        underlying = new MockToken("Dai Token", "DAI", mockUnderlyingDecimals);
        target = new MockTarget(address(underlying), "Compound Dai", "cDAI", mockTargetDecimals);
        reward = new MockToken("Reward Token", "RT", baseDecimals);
        if (mockUnderlyingDecimals != 18) {
            emit log_named_uint(
                "Running tests with the mock Underlying token configured with the following number of decimals",
                uint256(mockUnderlyingDecimals)
            );
        }
        if (mockTargetDecimals != 18) {
            emit log_named_uint(
                "Running tests with the mock Target token configured with the following number of decimals",
                uint256(mockTargetDecimals)
            );
        }
        SCALING_FACTOR =
            10 **
                (
                    mockTargetDecimals > mockUnderlyingDecimals
                        ? mockTargetDecimals - mockUnderlyingDecimals
                        : mockUnderlyingDecimals - mockTargetDecimals
                );
        GROWTH_PER_SECOND = convertToBase(GROWTH_PER_SECOND, target.decimals());
        tokenHandler = new TokenHandler();
        divider = new Divider(address(this), address(tokenHandler));
        tokenHandler.init(address(divider));
        SPONSOR_WINDOW = divider.SPONSOR_WINDOW();
        SETTLEMENT_WINDOW = divider.SETTLEMENT_WINDOW();
        balancerVault = new MockBalancerVault();
        spaceFactory = new MockSpaceFactory(address(balancerVault), address(divider));
        comptroller = new MockComptroller();
        fuseDirectory = new MockFuseDirectory(address(comptroller));
        masterOracle = new MockOracle();
        poolManager = new PoolManager(
            address(fuseDirectory),
            address(comptroller),
            address(1),
            address(divider),
            address(masterOracle) 
        );
        poolManager.deployPool("Sense Fuse Pool", 0.051 ether, 1 ether, address(1));
        PoolManager.AssetParams memory params = PoolManager.AssetParams({
            irModel: 0xEDE47399e2aA8f076d40DC52896331CBa8bd40f7,
            reserveFactor: 0.1 ether,
            collateralFactor: 0.5 ether
        });
        poolManager.setParams("TARGET_PARAMS", params);
        periphery = new Periphery(
            address(divider),
            address(poolManager),
            address(spaceFactory),
            address(balancerVault)
        );
        divider.setPeriphery(address(periphery));
        poolManager.setIsTrusted(address(periphery), true);
        gYTManager = new GYTManager(address(divider));
        DEFAULT_ADAPTER_PARAMS = BaseAdapter.AdapterParams({
            oracle: ORACLE,
            stake: address(stake),
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0,
            level: DEFAULT_LEVEL
        });
        factory = createFactory(address(target), address(reward));
        address f = periphery.deployAdapter(address(factory), address(target), ""); 
        adapter = MockAdapter(f);
        divider.setGuard(address(adapter), 10 * 2**128);
        alice = createUser(2**128, 2**128);
        bob = createUser(2**128, 2**128);
        jim = createUser(2**128, 2**128);
    }
    function createUser(uint256 tBal, uint256 sBal) public returns (User user) {
        user = new User();
        user.setFactory(factory);
        user.setStake(stake);
        user.setTarget(target);
        user.setDivider(divider);
        user.setPeriphery(periphery);
        user.doApprove(address(underlying), address(periphery));
        user.doApprove(address(underlying), address(divider));
        user.doMint(address(underlying), tBal);
        user.doApprove(address(stake), address(periphery));
        user.doApprove(address(stake), address(divider));
        user.doMint(address(stake), sBal);
        user.doApprove(address(target), address(periphery));
        user.doApprove(address(target), address(divider));
        user.doApprove(address(target), address(user.gYTManager()));
        user.doMint(address(target), tBal);
    }
    function updateUser(
        User user,
        MockToken target,
        MockToken stake,
        uint256 amt
    ) public {
        user.setStake(stake);
        user.setTarget(target);
        user.setDivider(divider);
        user.setPeriphery(periphery);
        user.doApprove(address(underlying), address(periphery));
        user.doApprove(address(underlying), address(divider));
        user.doMint(address(underlying), amt);
        user.doApprove(address(stake), address(periphery));
        user.doApprove(address(stake), address(divider));
        user.doMint(address(stake), amt);
        user.doApprove(address(target), address(periphery));
        user.doApprove(address(target), address(divider));
        user.doApprove(address(target), address(user.gYTManager()));
        user.doMint(address(target), amt);
    }
    function setupUser(
        address usr,
        address target,
        address stake,
        uint256 amt
    ) public returns (User user) {
        address underlying = MockTarget(target).underlying();
        MockToken(underlying).approve(address(periphery), type(uint256).max);
        MockToken(underlying).approve(address(divider), type(uint256).max);
        MockToken(underlying).mint(usr, amt);
        MockToken(stake).approve(address(periphery), type(uint256).max);
        MockToken(stake).approve(address(divider), type(uint256).max);
        MockToken(stake).mint(stake, amt);
        MockToken(target).approve(address(periphery), type(uint256).max);
        MockToken(target).approve(address(divider), type(uint256).max);
        MockToken(target).mint(usr, amt);
    }
    function createFactory(address _target, address _reward) public returns (MockFactory someFactory) {
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: address(stake),
            oracle: ORACLE,
            ifee: ISSUANCE_FEE,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0
        });
        someFactory = new MockFactory(address(divider), factoryParams, _reward); 
        someFactory.addTarget(_target, true);
        divider.setIsTrusted(address(someFactory), true);
        periphery.setFactory(address(someFactory), true);
    }
    function createCropsFactory(address _target, address[] memory _rewardTokens)
        public
        returns (MockCropsFactory someFactory)
    {
        BaseFactory.FactoryParams memory factoryParams = BaseFactory.FactoryParams({
            stake: address(stake),
            oracle: ORACLE,
            ifee: ISSUANCE_FEE,
            stakeSize: STAKE_SIZE,
            minm: MIN_MATURITY,
            maxm: MAX_MATURITY,
            mode: MODE,
            tilt: 0
        });
        someFactory = new MockCropsFactory(address(divider), factoryParams, _rewardTokens); 
        someFactory.addTarget(_target, true);
        divider.setIsTrusted(address(someFactory), true);
        periphery.setFactory(address(someFactory), true);
    }
    function getValidMaturity(uint256 year, uint256 month) public view returns (uint256 maturity) {
        maturity = DateTimeFull.timestampFromDateTime(year, month, 1, 0, 0, 0);
        if (maturity < block.timestamp + 2 weeks) revert Errors.InvalidMaturityOffsets();
    }
    function sponsorSampleSeries(address sponsor, uint256 maturity) public returns (address pt, address yt) {
        (pt, yt) = User(sponsor).doSponsorSeries(address(adapter), maturity);
    }
    function addLiquidityToBalancerVault(
        address adapter,
        uint256 maturity,
        uint256 tBal
    ) public {
        return _addLiquidityToBalancerVault(adapter, maturity, tBal);
    }
    function addLiquidityToBalancerVault(uint256 maturity, uint256 tBal) public {
        return _addLiquidityToBalancerVault(address(adapter), maturity, tBal);
    }
    function _addLiquidityToBalancerVault(
        address adapter,
        uint256 maturity,
        uint256 tBal
    ) internal {
        uint256 issued = alice.doIssue(adapter, maturity, tBal);
        alice.doTransfer(divider.yt(address(adapter), maturity), address(balancerVault), issued); 
        alice.doTransfer(divider.pt(address(adapter), maturity), address(balancerVault), issued);
        MockToken(MockAdapter(adapter).target()).mint(address(balancerVault), tBal);
    }
    function convertBase(uint256 decimals) internal pure returns (uint256) {
        uint256 base = 1;
        base = decimals > 18 ? 10**(decimals - 18) : 10**(18 - decimals);
        return base;
    }
    function convertToBase(uint256 amount, uint256 decimals) internal pure returns (uint256) {
        if (decimals != 18) {
            amount = decimals > 18 ? amount * 10**(decimals - 18) : amount / 10**(18 - decimals);
        }
        return amount;
    }
    function calculateAmountToIssue(uint256 tBal) public returns (uint256 toIssue) {
        (, uint256 cscale) = adapter.lscale();
        toIssue = tBal.fmul(cscale);
    }
    function calculateExcess(
        uint256 tBal,
        uint256 maturity,
        address yt
    ) public returns (uint256 gap) {
        uint256 toIssue = calculateAmountToIssue(tBal);
        gap = gYTManager.excess(address(adapter), maturity, toIssue);
    }
    function getError(uint256 errCode) internal pure returns (string memory errString) {
        return string(bytes.concat(bytes("SNS#"), bytes(Strings.toString(errCode))));
    }
    function toUint256(bytes memory _bytes) internal pure returns (uint256 value) {
        assembly {
            value := mload(add(_bytes, 0x20))
        }
    }
}