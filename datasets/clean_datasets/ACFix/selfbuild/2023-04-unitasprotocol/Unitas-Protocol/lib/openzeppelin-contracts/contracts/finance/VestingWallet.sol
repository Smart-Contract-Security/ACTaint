pragma solidity ^0.8.0;
import "../token/ERC20/utils/SafeERC20.sol";
import "../utils/Address.sol";
import "../utils/Context.sol";
contract VestingWallet is Context {
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);
    uint256 private _released;
    mapping(address => uint256) private _erc20Released;
    address private immutable _beneficiary;
    uint64 private immutable _start;
    uint64 private immutable _duration;
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) payable {
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
        Address.sendValue(payable(beneficiary()), amount);
    }
    function release(address token) public virtual {
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), amount);
    }
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }
    function vestedAmount(address token, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(IERC20(token).balanceOf(address(this)) + released(token), timestamp);
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
}