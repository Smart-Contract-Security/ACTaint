pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IEulerEToken} from "./external/IEulerEToken.sol";
contract EulerERC4626 is ERC4626 {
    using SafeTransferLib for ERC20;
    address public immutable euler;
    IEulerEToken public immutable eToken;
    constructor(ERC20 asset_, address euler_, IEulerEToken eToken_)
        ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        euler = euler_;
        eToken = eToken_;
    }
    function totalAssets() public view virtual override returns (uint256) {
        return eToken.balanceOfUnderlying(address(this));
    }
    function beforeWithdraw(uint256 assets, uint256  ) internal virtual override {
        eToken.withdraw(0, assets);
    }
    function afterDeposit(uint256 assets, uint256  ) internal virtual override {
        asset.safeApprove(address(euler), assets);
        eToken.deposit(0, assets);
    }
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 cash = asset.balanceOf(euler);
        uint256 assetsBalance = convertToAssets(balanceOf[owner]);
        return cash < assetsBalance ? cash : assetsBalance;
    }
    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 cash = asset.balanceOf(euler);
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }
    function _vaultName(ERC20 asset_) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("ERC4626-Wrapped Euler ", asset_.symbol());
    }
    function _vaultSymbol(ERC20 asset_) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("we", asset_.symbol());
    }
}