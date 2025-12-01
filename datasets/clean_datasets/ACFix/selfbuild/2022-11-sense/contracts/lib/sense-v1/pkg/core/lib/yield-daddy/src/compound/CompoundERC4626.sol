pragma solidity ^0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ICERC20} from "./external/ICERC20.sol";
import {LibCompound} from "./lib/LibCompound.sol";
import {IComptroller} from "./external/IComptroller.sol";
contract CompoundERC4626 is ERC4626 {
    using LibCompound for ICERC20;
    using SafeTransferLib for ERC20;
    event ClaimRewards(uint256 amount);
    error CompoundERC4626__CompoundError(uint256 errorCode);
    uint256 internal constant NO_ERROR = 0;
    ERC20 public immutable comp;
    ICERC20 public immutable cToken;
    address public immutable rewardRecipient;
    IComptroller public immutable comptroller;
    constructor(ERC20 asset_, ERC20 comp_, ICERC20 cToken_, address rewardRecipient_, IComptroller comptroller_)
        ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_))
    {
        comp = comp_;
        cToken = cToken_;
        comptroller = comptroller_;
        rewardRecipient = rewardRecipient_;
    }
    function claimRewards() external {
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        comptroller.claimComp(address(this), cTokens);
        uint256 amount = comp.balanceOf(address(this));
        comp.safeTransfer(rewardRecipient, amount);
        emit ClaimRewards(amount);
    }
    function totalAssets() public view virtual override returns (uint256) {
        return cToken.viewUnderlyingBalanceOf(address(this));
    }
    function beforeWithdraw(uint256 assets, uint256  ) internal virtual override {
        uint256 errorCode = cToken.redeemUnderlying(assets);
        if (errorCode != NO_ERROR) {
            revert CompoundERC4626__CompoundError(errorCode);
        }
    }
    function afterDeposit(uint256 assets, uint256  ) internal virtual override {
        asset.safeApprove(address(cToken), assets);
        uint256 errorCode = cToken.mint(assets);
        if (errorCode != NO_ERROR) {
            revert CompoundERC4626__CompoundError(errorCode);
        }
    }
    function maxDeposit(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) {
            return 0;
        }
        return type(uint256).max;
    }
    function maxMint(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) {
            return 0;
        }
        return type(uint256).max;
    }
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 cash = cToken.getCash();
        uint256 assetsBalance = convertToAssets(balanceOf[owner]);
        return cash < assetsBalance ? cash : assetsBalance;
    }
    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 cash = cToken.getCash();
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }
    function _vaultName(ERC20 asset_) internal view virtual returns (string memory vaultName) {
        vaultName = string.concat("ERC4626-Wrapped Compound ", asset_.symbol());
    }
    function _vaultSymbol(ERC20 asset_) internal view virtual returns (string memory vaultSymbol) {
        vaultSymbol = string.concat("wc", asset_.symbol());
    }
}