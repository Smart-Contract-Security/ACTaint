pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
abstract contract ExtractableReward is Trust {
    using SafeTransferLib for ERC20;
    address public rewardsRecipient;
    constructor(address _rewardsRecipient) Trust(msg.sender) {
        rewardsRecipient = _rewardsRecipient;
    }
    function _isValid(address _token) internal virtual returns (bool);
    function extractToken(address token) external {
        if (!_isValid(token)) revert Errors.TokenNotSupported();
        ERC20 t = ERC20(token);
        uint256 tBal = t.balanceOf(address(this));
        t.safeTransfer(rewardsRecipient, t.balanceOf(address(this)));
        emit RewardsClaimed(token, rewardsRecipient, tBal);
    }
    function setRewardsRecipient(address recipient) external requiresTrust {
        emit RewardsRecipientChanged(rewardsRecipient, recipient);
        rewardsRecipient = recipient;
    }
    event RewardsRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event RewardsClaimed(address indexed token, address indexed recipient, uint256 indexed amount);
}