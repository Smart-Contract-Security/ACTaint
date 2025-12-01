pragma solidity ^0.8.17;
import {PausableImpl} from "splits-utils/PausableImpl.sol";
import {TokenUtils} from "splits-utils/TokenUtils.sol";
import {WalletImpl} from "splits-utils/WalletImpl.sol";
contract PassThroughWalletImpl is WalletImpl, PausableImpl {
    using TokenUtils for address;
    struct InitParams {
        address owner;
        bool paused;
        address passThrough;
    }
    event SetPassThrough(address passThrough);
    event PassThrough(address[] tokens, uint256[] amounts);
    event ReceiveETH(uint256 amount);
    address public immutable passThroughWalletFactory;
    address internal $passThrough;
    constructor() {
        passThroughWalletFactory = msg.sender;
    }
    function initializer(InitParams calldata params_) external {
        if (msg.sender != passThroughWalletFactory) revert Unauthorized();
        __initPausable({owner_: params_.owner, paused_: params_.paused});
        $passThrough = params_.passThrough;
    }
    function setPassThrough(address passThrough_) external onlyOwner {
        $passThrough = passThrough_;
        emit SetPassThrough(passThrough_);
    }
    function passThrough() external view returns (address) {
        return $passThrough;
    }
    function passThroughTokens(address[] calldata tokens_) external pausable returns (uint256[] memory amounts) {
        address _passThrough = $passThrough;
        uint256 length = tokens_.length;
        amounts = new uint256[](length);
        for (uint256 i; i < length;) {
            address token = tokens_[i];
            uint256 amount = token._balanceOf(address(this));
            amounts[i] = amount;
            token._safeTransfer(_passThrough, amount);
            unchecked {
                ++i;
            }
        }
        emit PassThrough(tokens_, amounts);
    }
}