pragma solidity 0.8.9;
import "forge-std/Test.sol";
import "../../src/Testsupport/SupportsSWAP.sol";
import "../../src/token/JUSD.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MockUSDCPrice.sol";
import "../../src/oracle/JOJOOracleAdaptor.sol";
import "../mocks/MockChainLink.t.sol";
contract SupportSWAP is Test {
    SupportsSWAP public supportsSWAP;
    JUSD public jusd;
    MockERC20 public eth;
    MockERC20 public lido;
    JOJOOracleAdaptor public ethAdaptor;
    JOJOOracleAdaptor public lidoAdaptor;
    MockChainLink public ethChainLink;
    MockChainLink public lidoChainLink;
    MockUSDCPrice public usdcPrice;
    function setUp() public {
        jusd = new JUSD(6);
        eth = new MockERC20(10e18);
        lido = new MockERC20(10e18);
        ethChainLink = new MockChainLink();
        lidoChainLink = new MockChainLink();
        usdcPrice = new MockUSDCPrice();
        ethAdaptor = new JOJOOracleAdaptor(
            address(ethChainLink),
            20,
            86400,
            address(usdcPrice)
        );
        lidoAdaptor = new JOJOOracleAdaptor(
            address(lidoChainLink),
            20,
            86400,
            address(usdcPrice)
        );
        supportsSWAP = new SupportsSWAP(
            address(jusd),
            address(eth),
            address(ethAdaptor)
        );
    }
    function testAddToken() public {
        assertEq(ethAdaptor.getAssetPrice(), 1000e6);
        supportsSWAP.addTokenPrice(address(lido), address(lidoAdaptor));
        jusd.mint(5000e6);
        jusd.transfer(address(supportsSWAP), 5000e6);
        eth.transfer(address(supportsSWAP), 5e18);
        lido.transfer(address(supportsSWAP), 5e18);
        lido.transfer(address(123), 5e18);
        vm.startPrank(address(123));
        lido.approve(address(supportsSWAP), 5e18);
        supportsSWAP.swap(1e18, address(lido));
        assertEq(lido.balanceOf(address(123)), 4e18);
        assertEq(jusd.balanceOf(address(123)), 1000e6);
    }
}