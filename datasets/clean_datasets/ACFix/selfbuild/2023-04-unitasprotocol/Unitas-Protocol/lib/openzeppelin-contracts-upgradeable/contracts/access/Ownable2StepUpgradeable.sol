pragma solidity ^0.8.0;
import "./OwnableUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    function __Ownable2Step_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }
    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
    address private _pendingOwner;
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }
    function acceptOwnership() external {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }
    uint256[49] private __gap;
}