pragma solidity ^0.8.0;
import "../ERC20Upgradeable.sol";
import "../utils/SafeERC20Upgradeable.sol";
import "../../../interfaces/IERC4626Upgradeable.sol";
import "../../../utils/math/MathUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
abstract contract ERC4626Upgradeable is Initializable, ERC20Upgradeable, IERC4626Upgradeable {
    using MathUpgradeable for uint256;
    IERC20Upgradeable private _asset;
    uint8 private _decimals;
    function __ERC4626_init(IERC20Upgradeable asset_) internal onlyInitializing {
        __ERC4626_init_unchained(asset_);
    }
    function __ERC4626_init_unchained(IERC20Upgradeable asset_) internal onlyInitializing {
        uint8 decimals_;
        try IERC20MetadataUpgradeable(address(asset_)).decimals() returns (uint8 value) {
            decimals_ = value;
        } catch {
            decimals_ = super.decimals();
        }
        _asset = asset_;
        _decimals = decimals_;
    }
    function decimals() public view virtual override(IERC20MetadataUpgradeable, ERC20Upgradeable) returns (uint8) {
        return _decimals;
    }
    function asset() public view virtual override returns (address) {
        return address(_asset);
    }
    function totalAssets() public view virtual override returns (uint256) {
        return _asset.balanceOf(address(this));
    }
    function convertToShares(uint256 assets) public view virtual override returns (uint256 shares) {
        return _convertToShares(assets, MathUpgradeable.Rounding.Down);
    }
    function convertToAssets(uint256 shares) public view virtual override returns (uint256 assets) {
        return _convertToAssets(shares, MathUpgradeable.Rounding.Down);
    }
    function maxDeposit(address) public view virtual override returns (uint256) {
        return _isVaultCollateralized() ? type(uint256).max : 0;
    }
    function maxMint(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return _convertToAssets(balanceOf(owner), MathUpgradeable.Rounding.Down);
    }
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
    }
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, MathUpgradeable.Rounding.Down);
    }
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, MathUpgradeable.Rounding.Up);
    }
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return _convertToShares(assets, MathUpgradeable.Rounding.Up);
    }
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return _convertToAssets(shares, MathUpgradeable.Rounding.Down);
    }
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(assets <= maxDeposit(receiver), "ERC4626: deposit more than max");
        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        return shares;
    }
    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");
        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);
        return assets;
    }
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(assets <= maxWithdraw(owner), "ERC4626: withdraw more than max");
        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        return shares;
    }
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");
        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
        return assets;
    }
    function _convertToShares(uint256 assets, MathUpgradeable.Rounding rounding) internal view virtual returns (uint256 shares) {
        uint256 supply = totalSupply();
        return
            (assets == 0 || supply == 0)
                ? _initialConvertToShares(assets, rounding)
                : assets.mulDiv(supply, totalAssets(), rounding);
    }
    function _initialConvertToShares(
        uint256 assets,
        MathUpgradeable.Rounding 
    ) internal view virtual returns (uint256 shares) {
        return assets;
    }
    function _convertToAssets(uint256 shares, MathUpgradeable.Rounding rounding) internal view virtual returns (uint256 assets) {
        uint256 supply = totalSupply();
        return
            (supply == 0) ? _initialConvertToAssets(shares, rounding) : shares.mulDiv(totalAssets(), supply, rounding);
    }
    function _initialConvertToAssets(
        uint256 shares,
        MathUpgradeable.Rounding 
    ) internal view virtual returns (uint256 assets) {
        return shares;
    }
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        SafeERC20Upgradeable.safeTransferFrom(_asset, caller, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
    }
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);
        SafeERC20Upgradeable.safeTransfer(_asset, receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
    function _isVaultCollateralized() private view returns (bool) {
        return totalAssets() > 0 || totalSupply() == 0;
    }
    uint256[49] private __gap;
}