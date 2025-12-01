pragma solidity 0.8.9;
import "ds-test/test.sol";
import "../../src/Impl/JUSDBank.sol";
import "../mocks/MockERC20.sol";
import "../../src/token/JUSD.sol";
import "../../src/oracle/JOJOOracleAdaptor.sol";
import "../mocks/MockChainLink.t.sol";
import "../mocks/MockJOJODealer.sol";
import "../../src/lib/DataTypes.sol";
import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "@JOJO/contracts/testSupport/TestERC20.sol";
import "../mocks/MockUSDCPrice.sol";
import "../../src/lib/DecimalMath.sol";
interface Cheats {
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}
contract JUSDOperationTest is Test {
    Cheats internal constant cheats =
        Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    using DecimalMath for uint256;
    JUSDBank public jusdBank;
    MockERC20 public mockToken1;
    JUSD public jusd;
    JOJOOracleAdaptor public jojoOracle1;
    MockChainLink public mockToken1ChainLink;
    MockUSDCPrice public usdcPrice;
    MockJOJODealer public jojoDealer;
    TestERC20 public USDC;
    address internal alice = address(1);
    address internal bob = address(2);
    address internal insurance = address(3);
    function setUp() public {
        mockToken1 = new MockERC20(2000e18);
        jusd = new JUSD(6);
        mockToken1ChainLink = new MockChainLink();
        usdcPrice = new MockUSDCPrice();
        jojoDealer = new MockJOJODealer();
        jojoOracle1 = new JOJOOracleAdaptor(
            address(mockToken1ChainLink),
            20,
            86400,
            address(usdcPrice)
        );
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(insurance, "Insurance");
        jusd.mint(100000e6);
        USDC = new TestERC20("USDC", "USDC", 6);
        jusdBank = new JUSDBank( 
            2,
            insurance,
            address(jusd),
            address(jojoDealer),
            6000e18,
            9000e18,
            2e16,
            address(USDC)
        );
        jusdBank.initReserve(
            address(mockToken1),
            5e17,
            180e18,
            100e18,
            100000e18,
            9e17,
            5e16,
            1e16,
            address(jojoOracle1)
        );
    }
    function testJUSDMint() public {
        jusd.mint(100e6);
        assertEq(jusd.balanceOf(address(this)), 100100e6);
    }
    function testJUSDBurn() public {
        jusd.burn(50000e6);
        assertEq(jusd.balanceOf(address(this)), 50000e6);
    }
    function testJUSDDecimal() public {
        emit log_uint(jusd.decimals());
        assertEq(jusd.decimals(), 6);
    }
    function testInitReserveParamWrong() public {
        cheats.expectRevert("RESERVE_PARAM_ERROR");
        jusdBank.initReserve(
            address(mockToken1),
            5e17,
            180e18,
            100e18,
            100000e18,
            9e17,
            5e16,
            1e17,
            address(jojoOracle1)
        );
    }
    function updatePrimaryAsset() public {
        jusdBank.updatePrimaryAsset(address(123));
    }
    function testInitReserve() public {
        jusdBank.initReserve(
            address(mockToken1),
            5e17,
            180e18,
            100e18,
            100000e18,
            9e17,
            5e16,
            1e16,
            address(jojoOracle1)
        );
    }
    function testInitReserveTooMany() public {
        jusdBank.updateMaxReservesAmount(0);
        cheats.expectRevert("NO_MORE_RESERVE_ALLOWED");
        jusdBank.initReserve(
            address(mockToken1),
            5e17,
            180e18,
            100e18,
            100000e18,
            9e17,
            5e16,
            1e16,
            address(jojoOracle1)
        );
    }
    function testUpdateMaxBorrowAmount() public {
        jusdBank.updateMaxBorrowAmount(1000e18, 10000e18);
        assertEq(jusdBank.maxTotalBorrowAmount(), 10000e18);
    }
    function testUpdateRiskParam() public {
        jusdBank.updateRiskParam(address(mockToken1), 2e16, 2e17, 2e17);
    }
    function testUpdateRiskParamWrong() public {
        cheats.expectRevert("RESERVE_PARAM_ERROR");
        jusdBank.updateRiskParam(address(mockToken1), 9e17, 2e17, 2e17);
    }
    function testUpdateReserveParam() public {
        jusdBank.updateReserveParam(
            address(mockToken1),
            1e18,
            100e18,
            100e18,
            200000e18
        );
    }
    function testSetInsurance() public {
        jusdBank.updateInsurance(address(10));
        assertEq(jusdBank.insurance(), address(10));
    }
    function testSetJOJODealer() public {
        jusdBank.updateJOJODealer(address(10));
        assertEq(jusdBank.JOJODealer(), address(10));
    }
    function testSetOracle() public {
        jusdBank.updateOracle(address(mockToken1), address(10));
    }
    function testUpdateRate() public {
        jusdBank.updateBorrowFeeRate(1e18);
        assertEq(jusdBank.borrowFeeRate(), 1e18);
    }
    function testUpdatePrimaryAsset() public {
        jusdBank.updatePrimaryAsset(address(123));
        assertEq(jusdBank.primaryAsset(), address(123));
    }
    function testReserveList() public {
        address[] memory list = jusdBank.getReservesList();
        assertEq(list[0], address(mockToken1));
    }
    function testCollateralPrice() public {
        uint256 price = jusdBank.getCollateralPrice(address(mockToken1));
        assertEq(price, 1e9);
    }
    function testCollateraltMaxMintAmount() public {
        uint256 value = jusdBank.getCollateralMaxMintAmount(
            address(mockToken1),
            2e18
        );
        assertEq(value, 1000e6);
    }
}