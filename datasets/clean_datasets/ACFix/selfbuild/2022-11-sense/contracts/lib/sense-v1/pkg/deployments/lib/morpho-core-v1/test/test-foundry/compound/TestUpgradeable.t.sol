pragma solidity 0.8.13;
import "./setup/TestSetup.sol";
contract TestUpgradeable is TestSetup {
    using CompoundMath for uint256;
    function testUpgradeMorpho() public {
        uint256 amount = 10000 ether;
        supplier1.approve(dai, amount);
        supplier1.supply(cDai, amount);
        Morpho morphoImplV2 = new Morpho();
        hevm.record();
        proxyAdmin.upgrade(morphoProxy, address(morphoImplV2));
        (, bytes32[] memory writes) = hevm.accesses(address(morpho));
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            hevm.load(
                address(morphoProxy),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) 
            )
        );
        assertEq(newImplem, address(morphoImplV2));
    }
    function testOnlyProxyOwnerCanUpgradeMorpho() public {
        Morpho morphoImplV2 = new Morpho();
        hevm.prank(address(supplier1));
        hevm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(morphoProxy, address(morphoImplV2));
        proxyAdmin.upgrade(morphoProxy, address(morphoImplV2));
    }
    function testOnlyProxyOwnerCanUpgradeAndCallMorpho() public {
        Morpho morphoImplV2 = new Morpho();
        hevm.prank(address(supplier1));
        hevm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(morphoProxy, payable(address(morphoImplV2)), "");
        proxyAdmin.upgradeAndCall(morphoProxy, payable(address(morphoImplV2)), "");
    }
    function testUpgradeRewardsManager() public {
        RewardsManager rewardsManagerImplV2 = new RewardsManager();
        hevm.record();
        proxyAdmin.upgrade(rewardsManagerProxy, address(rewardsManagerImplV2));
        (, bytes32[] memory writes) = hevm.accesses(address(rewardsManager));
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            hevm.load(
                address(rewardsManagerProxy),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) 
            )
        );
        assertEq(newImplem, address(rewardsManagerImplV2));
    }
    function testOnlyProxyOwnerCanUpgradeRewardsManager() public {
        RewardsManager rewardsManagerImplV2 = new RewardsManager();
        hevm.prank(address(supplier1));
        hevm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(rewardsManagerProxy, address(rewardsManagerImplV2));
        proxyAdmin.upgrade(rewardsManagerProxy, address(rewardsManagerImplV2));
    }
    function testOnlyProxyOwnerCanUpgradeAndCallRewardsManager() public {
        RewardsManager rewardsManagerImplV2 = new RewardsManager();
        hevm.prank(address(supplier1));
        hevm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(rewardsManagerProxy, payable(address(rewardsManagerImplV2)), "");
        hevm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(rewardsManagerProxy, payable(address(rewardsManagerImplV2)), "");
    }
    function testRewardsManagerImplementationsShouldBeInitialized() public {
        hevm.expectRevert("Initializable: contract is already initialized");
        rewardsManagerImplV1.initialize(address(morpho));
    }
    function testUpgradeLens() public {
        Lens lensImplV2 = new Lens();
        hevm.record();
        proxyAdmin.upgrade(lensProxy, address(lensImplV2));
        (, bytes32[] memory writes) = hevm.accesses(address(lens));
        assertEq(writes.length, 1);
        address newImplem = bytes32ToAddress(
            hevm.load(
                address(lensProxy),
                bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1) 
            )
        );
        assertEq(newImplem, address(lensImplV2));
    }
    function testOnlyProxyOwnerCanUpgradeLens() public {
        Lens lensImplV2 = new Lens();
        hevm.prank(address(supplier1));
        hevm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(lensProxy, address(lensImplV2));
        proxyAdmin.upgrade(lensProxy, address(lensImplV2));
    }
    function testOnlyProxyOwnerCanUpgradeAndCallLens() public {
        Lens lensImplV2 = new Lens();
        hevm.prank(address(supplier1));
        hevm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgradeAndCall(lensProxy, payable(address(lensImplV2)), "");
        hevm.expectRevert("Address: low-level delegate call failed");
        proxyAdmin.upgradeAndCall(lensProxy, payable(address(lensImplV2)), "");
    }
    function testLensImplementationsShouldBeInitialized() public {
        hevm.expectRevert("Initializable: contract is already initialized");
        lensImplV1.initialize(address(morpho));
    }
    function testPositionsManagerImplementationsShouldBeInitialized() public {
        Types.MaxGasForMatching memory defaultMaxGasForMatching = Types.MaxGasForMatching({
            supply: 3e6,
            borrow: 3e6,
            withdraw: 3e6,
            repay: 3e6
        });
        hevm.expectRevert("Initializable: contract is already initialized");
        morphoImplV1.initialize(
            positionsManager,
            interestRatesManager,
            comptroller,
            defaultMaxGasForMatching,
            1,
            20,
            cEth,
            wEth
        );
        uint256 _initialized = uint256(hevm.load(address(positionsManager), bytes32(0)));
        assertEq(_initialized, 1);
    }
}