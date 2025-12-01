pragma solidity ^0.8.0;
import "../ERC20.sol";
import "../utils/SafeERC20.sol";
abstract contract ERC20Wrapper is ERC20 {
    IERC20 private immutable _underlying;
    constructor(IERC20 underlyingToken) {
        require(underlyingToken != this, "ERC20Wrapper: cannot self wrap");
        _underlying = underlyingToken;
    }
    function decimals() public view virtual override returns (uint8) {
        try IERC20Metadata(address(_underlying)).decimals() returns (uint8 value) {
            return value;
        } catch {
            return super.decimals();
        }
    }
    function underlying() public view returns (IERC20) {
        return _underlying;
    }
    function depositFor(address account, uint256 amount) public virtual returns (bool) {
        address sender = _msgSender();
        require(sender != address(this), "ERC20Wrapper: wrapper can't deposit");
        SafeERC20.safeTransferFrom(_underlying, sender, address(this), amount);
        _mint(account, amount);
        return true;
    }
    function withdrawTo(address account, uint256 amount) public virtual returns (bool) {
        _burn(_msgSender(), amount);
        SafeERC20.safeTransfer(_underlying, account, amount);
        return true;
    }
    function _recover(address account) internal virtual returns (uint256) {
        uint256 value = _underlying.balanceOf(address(this)) - totalSupply();
        _mint(account, value);
        return value;
    }
}