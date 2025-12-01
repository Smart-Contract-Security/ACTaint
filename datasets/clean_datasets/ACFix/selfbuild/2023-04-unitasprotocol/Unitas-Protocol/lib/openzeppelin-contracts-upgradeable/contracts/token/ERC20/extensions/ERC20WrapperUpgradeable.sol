pragma solidity ^0.8.0;
import "../ERC20Upgradeable.sol";
import "../utils/SafeERC20Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC20WrapperUpgradeable is Initializable, ERC20Upgradeable {
    IERC20Upgradeable public underlying;
    function __ERC20Wrapper_init(IERC20Upgradeable underlyingToken) internal onlyInitializing {
        __ERC20Wrapper_init_unchained(underlyingToken);
    }
    function __ERC20Wrapper_init_unchained(IERC20Upgradeable underlyingToken) internal onlyInitializing {
        underlying = underlyingToken;
    }
    function decimals() public view virtual override returns (uint8) {
        try IERC20MetadataUpgradeable(address(underlying)).decimals() returns (uint8 value) {
            return value;
        } catch {
            return super.decimals();
        }
    }
    function depositFor(address account, uint256 amount) public virtual returns (bool) {
        SafeERC20Upgradeable.safeTransferFrom(underlying, _msgSender(), address(this), amount);
        _mint(account, amount);
        return true;
    }
    function withdrawTo(address account, uint256 amount) public virtual returns (bool) {
        _burn(_msgSender(), amount);
        SafeERC20Upgradeable.safeTransfer(underlying, account, amount);
        return true;
    }
    function _recover(address account) internal virtual returns (uint256) {
        uint256 value = underlying.balanceOf(address(this)) - totalSupply();
        _mint(account, value);
        return value;
    }
    uint256[50] private __gap;
}