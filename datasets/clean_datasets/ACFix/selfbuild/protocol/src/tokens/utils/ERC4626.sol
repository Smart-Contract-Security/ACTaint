pragma solidity ^0.8.17;
import {Errors} from "../../utils/Errors.sol";
import {ERC20 as CustomERC20} from "./ERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
abstract contract ERC4626 is CustomERC20 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    ERC20 public asset;
    uint reserveShares;
    function initERC4626(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint _reserveShares,
        uint _maxSupply
    ) internal {
        asset = _asset;
        reserveShares = _reserveShares;
        initERC20(_name, _symbol, asset.decimals(), _maxSupply);
    }
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        beforeDeposit(assets, shares);
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
        if (totalSupply == 0 && decimals >= 6) {
            if (shares <= 10 ** (decimals - 2)) revert Errors.MinimumShares();
            _mint(address(0), reserveShares);
            shares -= reserveShares;
        }
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }
    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        beforeDeposit(assets, shares);
        assets = previewMint(shares); 
        if (totalSupply == 0 && decimals >= 6) {
            if (shares <= 10 ** (decimals - 2)) revert Errors.MinimumShares();
            _mint(address(0), reserveShares);
            shares -= reserveShares;
        }
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
        shares = previewWithdraw(assets); 
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; 
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        beforeWithdraw(assets, shares);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        asset.safeTransfer(receiver, assets);
    }
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; 
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");
        beforeWithdraw(assets, shares);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        asset.safeTransfer(receiver, assets);
    }
    function totalAssets() public view virtual returns (uint256);
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }
    function maxDeposit(address) public view virtual returns (uint256) {
        return convertToAssets(maxMint(address(0)));
    }
    function maxMint(address) public view virtual returns (uint256) {
        if (totalSupply >= maxSupply) return 0;
        return maxSupply - totalSupply;
    }
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }
    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}
    function beforeDeposit(uint256 assets, uint256 shares) internal virtual {}
}