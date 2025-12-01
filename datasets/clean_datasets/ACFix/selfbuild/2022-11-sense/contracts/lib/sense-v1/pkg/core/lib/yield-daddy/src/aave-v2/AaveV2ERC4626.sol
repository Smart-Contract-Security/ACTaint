pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IAaveMining} from "./external/IAaveMining.sol";
import {ILendingPool} from "./external/ILendingPool.sol";
contract AaveV2ERC4626 is ERC4626 {
    using SafeTransferLib for ERC20;
    event ClaimRewards(uint256 amount);
    uint256 internal constant ACTIVE_MASK = 1 << 56;
    uint256 internal constant FROZEN_MASK = 1 << 57;
    ERC20 public immutable aToken;
    IAaveMining public immutable aaveMining;
    address public immutable rewardRecipient;
    ILendingPool public immutable lendingPool;
    constructor(
        ERC20 asset_,
        ERC20 aToken_,
        IAaveMining aaveMining_,
        address rewardRecipient_,
        ILendingPool lendingPool_
    )
        ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        aToken = aToken_;
        aaveMining = aaveMining_;
        lendingPool = lendingPool_;
        rewardRecipient = rewardRecipient_;
    }
    function claimRewards() external {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        uint256 amount = aaveMining.claimRewards(assets, type(uint256).max, rewardRecipient);
        emit ClaimRewards(amount);
    }
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        returns (uint256 shares)
    {
        shares = previewWithdraw(assets); 
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; 
            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }
        beforeWithdraw(assets, shares);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        lendingPool.withdraw(address(asset), assets, receiver);
    }
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; 
            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - shares;
            }
        }
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");
        beforeWithdraw(assets, shares);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        lendingPool.withdraw(address(asset), assets, receiver);
    }
    function totalAssets() public view virtual override returns (uint256) {
        return aToken.balanceOf(address(this));
    }
    function afterDeposit(uint256 assets, uint256  ) internal virtual override {
        asset.safeApprove(address(lendingPool), assets);
        lendingPool.deposit(address(asset), assets, address(this), 0);
    }
    function maxDeposit(address) public view virtual override returns (uint256) {
        if (lendingPool.paused()) {
            return 0;
        }
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!(_getActive(configData) && !_getFrozen(configData))) {
            return 0;
        }
        return type(uint256).max;
    }
    function maxMint(address) public view virtual override returns (uint256) {
        if (lendingPool.paused()) {
            return 0;
        }
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!(_getActive(configData) && !_getFrozen(configData))) {
            return 0;
        }
        return type(uint256).max;
    }
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        if (lendingPool.paused()) {
            return 0;
        }
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!_getActive(configData)) {
            return 0;
        }
        uint256 cash = asset.balanceOf(address(aToken));
        uint256 assetsBalance = convertToAssets(balanceOf[owner]);
        return cash < assetsBalance ? cash : assetsBalance;
    }
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        if (lendingPool.paused()) {
            return 0;
        }
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!_getActive(configData)) {
            return 0;
        }
        uint256 cash = asset.balanceOf(address(aToken));
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }
    function _vaultName(ERC20 asset_) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("ERC4626-Wrapped Aave v2 ", asset_.symbol());
    }
    function _vaultSymbol(ERC20 asset_) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("wa2", asset_.symbol());
    }
    function _getActive(uint256 configData) internal pure returns (bool) {
        return (configData & ACTIVE_MASK) != 0;
    }
    function _getFrozen(uint256 configData) internal pure returns (bool) {
        return (configData & FROZEN_MASK) != 0;
    }
}