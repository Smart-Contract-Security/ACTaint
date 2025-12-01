pragma solidity 0.8.9;
import "ds-test/test.sol";
import "../../src/Impl/JUSDBank.sol";
import "../mocks/MockERC20.sol";
import "../../src/token/JUSD.sol";
import "../../src/oracle/JOJOOracleAdaptor.sol";
import "../mocks/MockChainLink.t.sol";
import "../mocks/MockJOJODealer.sol";
import "../../src/lib/DataTypes.sol";
import "@JOJO/contracts/subaccount/Subaccount.sol";
import "@JOJO/contracts/impl/JOJODealer.sol";
import "@JOJO/contracts/intf/IDealer.sol";
import "@JOJO/contracts/subaccount/SubaccountFactory.sol";
import "@JOJO/contracts/testSupport/TestERC20.sol";
import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/Impl/JUSDExchange.sol";
import "../../src/Impl/flashloanImpl/FlashLoanRepay.sol";
import "../../src/Testsupport/SupportsSWAP.sol";
import "../mocks/MockChainLinkBadDebt.sol";
import "../../src/lib/DecimalMath.sol";
import "../mocks/MockUSDCPrice.sol";
interface Cheats {
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}
contract SubaccountTest is Test {
    Cheats internal constant cheats =
        Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    using DecimalMath for uint256;
    JUSDBank public jusdBank;
    MockERC20 public mockToken1;
    TestERC20 public USDC;
    JUSD public jusd;
    JOJOOracleAdaptor public jojoOracle1;
    MockChainLink public mockToken1ChainLink;
    MockUSDCPrice public usdcPrice;
    JOJODealer public jojoDealer;
    SubaccountFactory public subaccountFactory;
    JUSDExchange jusdExchange;
    FlashLoanRepay public flashLoanRepay;
    SupportsSWAP public supportsSWAP;
    address internal alice = address(1);
    address internal bob = address(2);
    address internal insurance = address(3);
    function setUp() public {
        mockToken1 = new MockERC20(2000e18);
        jusd = new JUSD(6);
        USDC = new TestERC20("USDC", "USDC", 6);
        mockToken1ChainLink = new MockChainLink();
        usdcPrice = new MockUSDCPrice();
        jojoDealer = new JOJODealer(address(USDC));
        jojoOracle1 = new JOJOOracleAdaptor(
            address(mockToken1ChainLink),
            20,
            86400,
            address(usdcPrice)
        );
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(insurance, "Insurance");
        jusd.mint(200000e6);
        subaccountFactory = new SubaccountFactory();
        jusdExchange = new JUSDExchange(address(USDC), address(jusd));
        jusd.transfer(address(jusdExchange), 100000e6);
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
        jusd.transfer(address(jusdBank), 100000e6);
        flashLoanRepay = new FlashLoanRepay(
            address(jusdBank),
            address(jusdExchange),
            address(USDC),
            address(jusd)
        );
        supportsSWAP = new SupportsSWAP(
            address(USDC),
            address(mockToken1),
            address(jojoOracle1)
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
    function getSetOperatorData(
        address op,
        bool isValid
    ) public pure returns (bytes memory) {
        return
            abi.encodeWithSignature("setOperator(address,bool) ", op, isValid);
    }
    function testOperatorJOJOSubaccount() public {
        mockToken1.transfer(alice, 10e18);
        address[] memory user = new address[](2);
        user[0] = alice;
        user[1] = address(supportsSWAP);
        uint256[] memory amount = new uint256[](2);
        amount[0] = 1000e6;
        amount[1] = 100000e6;
        USDC.mint(user, amount);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        address aliceSub = subaccountFactory.newSubaccount();
        bytes memory data = jojoDealer.getSetOperatorCallData(alice, true);
        Subaccount(aliceSub).execute(address(jojoDealer), data, 0);
        assertEq(IDealer(jojoDealer).isOperatorValid(aliceSub, alice), true);
        jusdBank.deposit(alice, address(mockToken1), 1e18, aliceSub);
        jusdBank.setOperator(aliceSub, true);
        bytes memory dataDeposit = jusdBank.getDepositData(
            alice,
            address(mockToken1),
            1e18,
            aliceSub
        );
        bytes memory dataBorrow = jusdBank.getBorrowData(
            500e6,
            aliceSub,
            false
        );
        bytes[] memory multiCallData = new bytes[](2);
        multiCallData[0] = dataDeposit;
        multiCallData[1] = dataBorrow;
        bytes memory excuteData = abi.encodeWithSignature(
            "multiCall(bytes[])",
            multiCallData
        );
        Subaccount(aliceSub).execute(address(jusdBank), excuteData, 0);
        console.log(
            "aliceSub deposit",
            jusdBank.getDepositBalance(address(mockToken1), aliceSub)
        );
        console.log("aliceSub borrow", jusdBank.getBorrowBalance(aliceSub));
        console.log("alice borrow", jusdBank.getBorrowBalance(alice));
        bytes memory dataWithdraw = jusdBank.getWithdrawData(
            address(mockToken1),
            5e17,
            alice,
            false
        );
        Subaccount(aliceSub).execute(address(jusdBank), dataWithdraw, 0);
        console.log(
            "aliceSub deposit",
            jusdBank.getDepositBalance(address(mockToken1), aliceSub)
        );
        bytes memory swapParam = abi.encodeWithSignature(
            "swap(uint256,address)",
            2e17,
            address(mockToken1)
        );
        bytes memory param = abi.encode(
            address(supportsSWAP),
            address(supportsSWAP),
            200e6,
            swapParam
        );
        bytes memory dataFlashloan = abi.encodeWithSignature(
            "flashLoan(address,address,uint256,address,bytes)",
            address(flashLoanRepay),
            address(mockToken1),
            2e17,
            aliceSub,
            param
        );
        Subaccount(aliceSub).execute(address(jusdBank), dataFlashloan, 0);
        console.log("aliceSub borrow", jusdBank.getBorrowBalance(aliceSub));
        jusdBank.deposit(alice, address(mockToken1), 1e18, alice);
        swapParam = abi.encodeWithSignature(
            "swap(uint256,address)",
            3e17,
            address(mockToken1)
        );
        param = abi.encode(
            address(supportsSWAP),
            address(supportsSWAP),
            300e6,
            swapParam
        );
        jusdBank.flashLoan(
            address(flashLoanRepay),
            address(mockToken1),
            3e17,
            aliceSub,
            param
        );
        console.log("aliceSub borrow", jusdBank.getBorrowBalance(aliceSub));
        assertEq(jusdBank.getBorrowBalance(aliceSub), 0);
        vm.stopPrank();
        vm.startPrank(bob);
        bytes memory dataBob = jojoDealer.getSetOperatorCallData(bob, true);
        cheats.expectRevert("Ownable: caller is not the owner");
        Subaccount(aliceSub).execute(address(jusdBank), dataBob, 0);
    }
}