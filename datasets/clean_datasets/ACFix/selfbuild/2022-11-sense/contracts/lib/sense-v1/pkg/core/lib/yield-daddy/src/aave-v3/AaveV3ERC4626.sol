pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IPool} from "./external/IPool.sol";
import {IRewardsController} from "./external/IRewardsController.sol";
contract AaveV3ERC4626 is ERC4626 {
    using SafeTransferLib for ERC20;
    event ClaimRewards(uint256 amount);
    uint256 internal constant DECIMALS_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF;
    uint256 internal constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
    uint256 internal constant PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;
    uint256 internal constant SUPPLY_CAP_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFF000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 116;
    uint256 internal constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    ERC20 public immutable aToken;
    IPool public immutable lendingPool;
    address public immutable rewardRecipient;
    IRewardsController public immutable rewardsController;
    constructor(
        ERC20 asset_,
        ERC20 aToken_,
        IPool lendingPool_,
        address rewardRecipient_,
        IRewardsController rewardsController_
    )
        ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        aToken = aToken_;
        lendingPool = lendingPool_;
        rewardRecipient = rewardRecipient_;
        rewardsController = rewardsController_;
    }
    function claimRewards() external {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        (, uint256[] memory claimedAmounts) = rewardsController.claimAllRewards(assets, rewardRecipient);
        emit ClaimRewards(claimedAmounts[0]);
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
        lendingPool.supply(address(asset), assets, address(this), 0);
    }
    function maxDeposit(address) public view virtual override returns (uint256) {
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!(_getActive(configData) && !_getFrozen(configData) && !_getPaused(configData))) {
            return 0;
        }
        uint256 supplyCapInWholeTokens = _getSupplyCap(configData);
        if (supplyCapInWholeTokens == 0) {
            return type(uint256).max;
        }
        uint8 tokenDecimals = _getDecimals(configData);
        uint256 supplyCap = supplyCapInWholeTokens * 10 ** tokenDecimals;
        return supplyCap - aToken.totalSupply();
    }
    function maxMint(address) public view virtual override returns (uint256) {
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!(_getActive(configData) && !_getFrozen(configData) && !_getPaused(configData))) {
            return 0;
        }
        uint256 supplyCapInWholeTokens = _getSupplyCap(configData);
        if (supplyCapInWholeTokens == 0) {
            return type(uint256).max;
        }
        uint8 tokenDecimals = _getDecimals(configData);
        uint256 supplyCap = supplyCapInWholeTokens * 10 ** tokenDecimals;
        return convertToShares(supplyCap - aToken.totalSupply());
    }
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!(_getActive(configData) && !_getPaused(configData))) {
            return 0;
        }
        uint256 cash = asset.balanceOf(address(aToken));
        uint256 assetsBalance = convertToAssets(balanceOf[owner]);
        return cash < assetsBalance ? cash : assetsBalance;
    }
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        uint256 configData = lendingPool.getReserveData(address(asset)).configuration.data;
        if (!(_getActive(configData) && !_getPaused(configData))) {
            return 0;
        }
        uint256 cash = asset.balanceOf(address(aToken));
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }
    function _vaultName(ERC20 asset_) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("ERC4626-Wrapped Aave v3 ", asset_.symbol());
    }
    function _vaultSymbol(ERC20 asset_) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("wa", asset_.symbol());
    }
    function _getDecimals(uint256 configData) internal pure returns (uint8) {
        return uint8((configData & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION);
    }
    function _getActive(uint256 configData) internal pure returns (bool) {
        return configData & ~ACTIVE_MASK != 0;
    }
    function _getFrozen(uint256 configData) internal pure returns (bool) {
        return configData & ~FROZEN_MASK != 0;
    }
    function _getPaused(uint256 configData) internal pure returns (bool) {
        return configData & ~PAUSED_MASK != 0;
    }
    function _getSupplyCap(uint256 configData) internal pure returns (uint256) {
        return (configData & ~SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION;
    }
}