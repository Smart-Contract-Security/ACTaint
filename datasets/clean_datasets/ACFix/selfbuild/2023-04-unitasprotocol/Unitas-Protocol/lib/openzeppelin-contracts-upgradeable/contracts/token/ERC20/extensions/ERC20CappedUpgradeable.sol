pragma solidity ^0.8.0;
import "../ERC20Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC20CappedUpgradeable is Initializable, ERC20Upgradeable {
    uint256 private _cap;
    function __ERC20Capped_init(uint256 cap_) internal onlyInitializing {
        __ERC20Capped_init_unchained(cap_);
    }
    function __ERC20Capped_init_unchained(uint256 cap_) internal onlyInitializing {
        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;
    }
    function cap() public view virtual returns (uint256) {
        return _cap;
    }
    function _mint(address account, uint256 amount) internal virtual override {
        require(ERC20Upgradeable.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }
    uint256[50] private __gap;
}