pragma solidity >=0.8.0;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
abstract contract ERC4626 is ERC20 {
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
    ERC20 public immutable asset;
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {
        asset = _asset;
    }
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        afterDeposit(assets, shares);
    }
    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
        assets = previewMint(shares); 
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        afterDeposit(assets, shares);
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
        return
            (assets == 0 || supply == 0)
                ? assets.mulDivDown(10**decimals, 10**asset.decimals())
                : assets.mulDivDown(supply, totalAssets());
    }
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply;
        return
            (supply == 0)
                ? shares.mulDivDown(10**asset.decimals(), 10**decimals)
                : shares.mulDivDown(totalAssets(), supply);
    }
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return
            (supply == 0)
                ? shares.mulDivUp(10**asset.decimals(), 10**decimals)
                : shares.mulDivUp(totalAssets(), supply);
    }
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return
            (supply == 0)
                ? assets.mulDivUp(10**decimals, 10**asset.decimals())
                : assets.mulDivUp(supply, totalAssets());
    }
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }
    function maxDeposit(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return balanceOf[owner];
    }
    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}
    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}