pragma solidity ^0.8.17;
import {LToken} from "./LToken.sol";
import {Errors} from "../utils/Errors.sol";
import {Helpers} from "../utils/Helpers.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IRegistry} from "../interface/core/IRegistry.sol";
interface IWETH {
    function withdraw(uint) external;
    function deposit() external payable;
}
contract LEther is LToken {
    using Helpers for address;
    function depositEth() external payable returns (uint shares) {
        uint assets = msg.value;
        beforeDeposit(assets, shares);
        if ((shares = previewDeposit(assets)) == 0) revert Errors.ZeroShares();
        IWETH(address(asset)).deposit{value: assets}();
        _mint(msg.sender, shares);
        emit Deposit(msg.sender, msg.sender, assets, shares);
    }
    function redeemEth(uint shares) external returns (uint assets) {
        if ((assets = previewRedeem(shares)) == 0) revert Errors.ZeroAssets();
        beforeWithdraw(assets, shares);
        _burn(msg.sender, shares);
        emit Withdraw(msg.sender, msg.sender, msg.sender, assets, shares);
        IWETH(address(asset)).withdraw(assets);
        msg.sender.safeTransferEth(assets);
    }
    receive() external payable {}
}