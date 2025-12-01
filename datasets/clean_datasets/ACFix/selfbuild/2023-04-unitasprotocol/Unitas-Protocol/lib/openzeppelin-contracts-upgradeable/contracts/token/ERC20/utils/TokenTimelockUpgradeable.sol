pragma solidity ^0.8.0;
import "./SafeERC20Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
contract TokenTimelockUpgradeable is Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable private _token;
    address private _beneficiary;
    uint256 private _releaseTime;
    function __TokenTimelock_init(
        IERC20Upgradeable token_,
        address beneficiary_,
        uint256 releaseTime_
    ) internal onlyInitializing {
        __TokenTimelock_init_unchained(token_, beneficiary_, releaseTime_);
    }
    function __TokenTimelock_init_unchained(
        IERC20Upgradeable token_,
        address beneficiary_,
        uint256 releaseTime_
    ) internal onlyInitializing {
        require(releaseTime_ > block.timestamp, "TokenTimelock: release time is before current time");
        _token = token_;
        _beneficiary = beneficiary_;
        _releaseTime = releaseTime_;
    }
    function token() public view virtual returns (IERC20Upgradeable) {
        return _token;
    }
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    function releaseTime() public view virtual returns (uint256) {
        return _releaseTime;
    }
    function release() public virtual {
        require(block.timestamp >= releaseTime(), "TokenTimelock: current time is before release time");
        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");
        token().safeTransfer(beneficiary(), amount);
    }
    uint256[50] private __gap;
}