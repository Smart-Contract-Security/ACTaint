pragma solidity 0.8.13;
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { ERC4626Factory } from "@yield-daddy/src/base/ERC4626Factory.sol";
abstract contract ERC4626WrapperFactory is ERC4626Factory, Trust {
    address public restrictedAdmin;
    address public rewardsRecipient;
    constructor(address _restrictedAdmin, address _rewardsRecipient) Trust(msg.sender) {
        restrictedAdmin = _restrictedAdmin;
        rewardsRecipient = _rewardsRecipient;
    }
    function setRestrictedAdmin(address _restrictedAdmin) external requiresTrust {
        emit RestrictedAdminChanged(restrictedAdmin, _restrictedAdmin);
        restrictedAdmin = _restrictedAdmin;
    }
    function setRewardsRecipient(address _recipient) external requiresTrust {
        emit RewardsRecipientChanged(rewardsRecipient, _recipient);
        rewardsRecipient = _recipient;
    }
    event RestrictedAdminChanged(address indexed restrictedAdmin, address indexed newRestrictedAdmin);
    event RewardsRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
}