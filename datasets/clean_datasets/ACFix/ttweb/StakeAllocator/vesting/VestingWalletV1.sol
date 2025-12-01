pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../errors/GeneralErrors.sol";
contract VestingWalletV1 is OwnableUpgradeable, UUPSUpgradeable {
    constructor() initializer
    {}
    mapping (address => uint256) private _released;
    address private _beneficiary;
    uint256 private _start;
    uint256 private _cliff;
    uint256 private _duration;
    event TokensReleased(address indexed token, uint256 amount);
    error DurationShorterThanCliff();
    modifier onlyBeneficiary() {
        if (beneficiary() != _msgSender()) revert DoesNotHaveAccess(_msgSender(), "beneficiary");
        _;
    }
    function initialize(
        address beneficiary_,
        address admin_,
        uint256 start_,
        uint256 cliff_,
        uint256 duration_
    ) external initializer {
        if (beneficiary_ == address(0x0)) revert ZeroAddress("beneficiary_");
        if(cliff_ > duration_) revert DurationShorterThanCliff();
        __Ownable_init();
        __UUPSUpgradeable_init();
        if (admin_ == address(0)) {
            renounceOwnership();
        } else {
            transferOwnership(admin_);
        }
        _beneficiary = beneficiary_;
        _start = start_;
        _cliff = cliff_;
        _duration = duration_;
    }
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    function start() public view virtual returns (uint256) {
        return _start;
    }
    function cliff() public view virtual returns (uint256) {
        return _cliff;
    }
    function duration() public view virtual returns (uint256) {
        return _duration;
    }
    function released(address token) public view returns (uint256) {
        return _released[token];
    }
    function release(address token) public {
        uint256 releasable = Math.min(
            vestedAmount(token, block.timestamp) - released(token),
            IERC20(token).balanceOf(address(this))
        );
        _released[token] += releasable;
        emit TokensReleased(token, releasable);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), releasable);
    }
    function vestedAmount(address token, uint256 timestamp) public virtual view returns (uint256) {
        if (timestamp < start() + cliff()) {
            return 0;
        } else if (timestamp >= start() + duration()) {
            return _historicalBalance(token);
        } else {
            return _historicalBalance(token) * (timestamp - start()) / duration();
        }
    }
    function _historicalBalance(address token) internal virtual view returns (uint256) {
        return IERC20(token).balanceOf(address(this)) + released(token);
    }
    function delegate(address token, address delegatee) public onlyBeneficiary() {
        ERC20Votes(token).delegate(delegatee);
    }
    function _authorizeUpgrade(address newImplementation)
    internal virtual override onlyOwner()
    {}
    uint256[45] private __gap;
}