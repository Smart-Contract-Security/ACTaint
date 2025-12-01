pragma solidity ^0.8.11;
import { DSTestPlus } from "solmate/test/utils/DSTestPlus.sol";
import { EulerERC4626WrapperFactory } from "../../../../adapters/abstract/erc4626/yield-daddy/euler/EulerERC4626WrapperFactory.sol";
import { Constants } from "../../../test-helpers/Constants.sol";
import { EulerMarketsMock } from "@yield-daddy/src/test/euler/mocks/EulerMarketsMock.sol";
contract ERC4626WrapperFactoryTest is DSTestPlus {
    EulerERC4626WrapperFactory public factory;
    function setUp() public {
        EulerMarketsMock markets = new EulerMarketsMock();
        factory = new EulerERC4626WrapperFactory(
            address(0xeee),
            markets,
            Constants.RESTRICTED_ADMIN,
            Constants.REWARDS_RECIPIENT
        );
        assertEq(factory.rewardsRecipient(), Constants.REWARDS_RECIPIENT);
        assertEq(factory.restrictedAdmin(), Constants.RESTRICTED_ADMIN);
    }
    function testSetRestrictedAdmin() public {
        assertEq(factory.restrictedAdmin(), Constants.RESTRICTED_ADMIN);
        hevm.expectRevert("UNTRUSTED");
        hevm.prank(address(0x123));
        factory.setRestrictedAdmin(address(0x111));
        hevm.expectEmit(true, true, true, true);
        emit RestrictedAdminChanged(Constants.RESTRICTED_ADMIN, address(0x111));
        factory.setRestrictedAdmin(address(0x111));
        assertEq(factory.restrictedAdmin(), address(0x111));
    }
    function testSetRewardsRecipient() public {
        assertEq(factory.rewardsRecipient(), Constants.REWARDS_RECIPIENT);
        hevm.expectRevert("UNTRUSTED");
        hevm.prank(address(0x123));
        factory.setRewardsRecipient(address(0x111));
        hevm.expectEmit(true, true, true, true);
        emit RewardsRecipientChanged(Constants.REWARDS_RECIPIENT, address(0x111));
        factory.setRewardsRecipient(address(0x111));
        assertEq(factory.rewardsRecipient(), address(0x111));
    }
    event RewardsRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event RestrictedAdminChanged(address indexed oldAdmin, address indexed newAdmin);
}