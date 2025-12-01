pragma solidity ^0.8.0;
import "../token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../utils/AddressUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
contract VestingWalletUpgradeable is Initializable, ContextUpgradeable {
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);
    uint256 private _released;
    mapping(address => uint256) private _erc20Released;
    address private _beneficiary;
    uint64 private _start;
    uint64 private _duration;
    function __VestingWallet_init(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) internal onlyInitializing {
        __VestingWallet_init_unchained(beneficiaryAddress, startTimestamp, durationSeconds);
    }
    function __VestingWallet_init_unchained(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) internal onlyInitializing {
        require(beneficiaryAddress != address(0), "VestingWallet: beneficiary is zero address");
        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _duration = durationSeconds;
    }
    receive() external payable virtual {}
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    function start() public view virtual returns (uint256) {
        return _start;
    }
    function duration() public view virtual returns (uint256) {
        return _duration;
    }
    function released() public view virtual returns (uint256) {
        return _released;
    }
    function released(address token) public view virtual returns (uint256) {
        return _erc20Released[token];
    }
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }
    function releasable(address token) public view virtual returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }
    function release() public virtual {
        uint256 amount = releasable();
        _released += amount;
        emit EtherReleased(amount);
        AddressUpgradeable.sendValue(payable(beneficiary()), amount);
    }
    function release(address token) public virtual {
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(token), beneficiary(), amount);
    }
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }
    function vestedAmount(address token, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(IERC20Upgradeable(token).balanceOf(address(this)) + released(token), timestamp);
    }
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }
    uint256[48] private __gap;
}