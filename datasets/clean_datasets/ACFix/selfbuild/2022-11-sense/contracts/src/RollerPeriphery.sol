pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { AutoRoller } from "./AutoRoller.sol";
contract RollerPeriphery {
    using SafeTransferLib for ERC20;
    error MinAssetError();
    error MinSharesError();
    error MaxAssetError();
    error MaxSharesError();
    error MinAssetsOrExcessError();
    function redeem(ERC4626 vault, uint256 shares, address receiver, uint256 minAmountOut) external returns (uint256 assets) {
        if ((assets = vault.redeem(shares, receiver, msg.sender)) < minAmountOut) {
            revert MinAssetError();
        }
    }
    function withdraw(ERC4626 vault, uint256 assets, address receiver, uint256 maxSharesOut) external returns (uint256 shares) {
        if ((shares = vault.withdraw(assets, receiver, msg.sender)) > maxSharesOut) {
            revert MaxSharesError();
        }
    }
    function mint(ERC4626 vault, uint256 shares, address receiver, uint256 maxAmountIn) external returns (uint256 assets) {
        ERC20(vault.asset()).safeTransferFrom(msg.sender, address(this), vault.previewMint(shares));
        if ((assets = vault.mint(shares, receiver)) > maxAmountIn) {
            revert MaxAssetError();
        }
    }
    function deposit(ERC4626 vault, uint256 assets, address receiver, uint256 minSharesOut) external returns (uint256 shares) {
        ERC20(vault.asset()).safeTransferFrom(msg.sender, address(this), assets);
        if ((shares = vault.deposit(assets, receiver)) < minSharesOut) {
            revert MinSharesError();
        }
    }
    function eject(ERC4626 vault, uint256 shares, address receiver, uint256 minAssetsOut, uint256 minExcessOut)
        external returns (uint256 assets, uint256 excessBal, bool isExcessPTs)
    {
        (assets, excessBal, isExcessPTs) = AutoRoller(address(vault)).eject(shares, receiver, msg.sender);
        if (assets < minAssetsOut || excessBal < minExcessOut) {
            revert MinAssetsOrExcessError();
        }
    }
    function approve(ERC20 token, address to, uint256 amount) public payable {
        token.safeApprove(to, amount);
    }
}