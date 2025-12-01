pragma solidity 0.8.9;
import "forge-std/Test.sol";
import "../../src/Testsupport/SupportChainLink.sol";
contract ChainlinkSupports is Test {
    SupportChainLink public supportChainLink;
    function setUp() public {
        supportChainLink = new SupportChainLink();
    }
    function testSetAssetPrice() public {
        supportChainLink.setAssetPrice(100e6);
        assertEq(supportChainLink.getAssetPrice(), 100e6);
    }
}