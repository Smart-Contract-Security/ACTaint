pragma solidity ^0.8.9;
import "./JUSDBankStorage.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";
import "../Interface/IJUSDBank.sol";
import {IPriceChainLink} from "../Interface/IPriceChainLink.sol";
abstract contract JUSDView is JUSDBankStorage, IJUSDBank {
    using DecimalMath for uint256;
    function getReservesList() external view returns (address[] memory) {
        return reservesList;
    }
    function getDepositMaxMintAmount(
        address user
    ) external view returns (uint256) {
        DataTypes.UserInfo storage userInfo = userInfo[user];
        return _maxMintAmountBorrow(userInfo);
    }
    function getCollateralMaxMintAmount(
        address collateral,
        uint256 amount
    ) external view returns (uint256 maxAmount) {
        DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
        return _getMintAmountBorrow(reserve, amount);
    }
    function getMaxWithdrawAmount(
        address collateral,
        address user
    ) external view returns (uint256 maxAmount) {
        DataTypes.UserInfo storage userInfo = userInfo[user];
        uint256 JUSDBorrow = userInfo.t0BorrowBalance.decimalMul(getTRate());
        if (JUSDBorrow == 0) {
            return userInfo.depositBalance[collateral];
        }
        uint256 maxMintAmount = _maxMintAmount(userInfo);
        if (maxMintAmount <= JUSDBorrow) {
            maxAmount = 0;
        } else {
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            uint256 remainAmount = (maxMintAmount - JUSDBorrow).decimalDiv(
                reserve.initialMortgageRate.decimalMul(
                    IPriceChainLink(reserve.oracle).getAssetPrice()
                )
            );
            remainAmount >= userInfo.depositBalance[collateral]
                ? maxAmount = userInfo.depositBalance[collateral]
                : maxAmount = remainAmount;
        }
    }
    function isAccountSafe(address user) external view returns (bool) {
        DataTypes.UserInfo storage userInfo = userInfo[user];
        return !_isStartLiquidation(userInfo, getTRate());
    }
    function getCollateralPrice(
        address collateral
    ) external view returns (uint256) {
        return IPriceChainLink(reserveInfo[collateral].oracle).getAssetPrice();
    }
    function getIfHasCollateral(
        address from,
        address collateral
    ) external view returns (bool) {
        return userInfo[from].hasCollateral[collateral];
    }
    function getDepositBalance(
        address collateral,
        address from
    ) external view returns (uint256) {
        return userInfo[from].depositBalance[collateral];
    }
    function getBorrowBalance(address from) external view returns (uint256) {
        return (userInfo[from].t0BorrowBalance * getTRate()) / 1e18;
    }
    function getUserCollateralList(
        address from
    ) external view returns (address[] memory) {
        return userInfo[from].collateralList;
    }
    function _getMintAmount(
        uint256 balance,
        address oracle,
        uint256 rate
    ) internal view returns (uint256) {
        return
            IPriceChainLink(oracle)
                .getAssetPrice()
                .decimalMul(balance)
                .decimalMul(rate);
    }
    function _getMintAmountBorrow(
        DataTypes.ReserveInfo memory reserve,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 depositAmount = IPriceChainLink(reserve.oracle)
            .getAssetPrice()
            .decimalMul(amount)
            .decimalMul(reserve.initialMortgageRate);
        if (depositAmount >= reserve.maxColBorrowPerAccount) {
            depositAmount = reserve.maxColBorrowPerAccount;
        }
        return depositAmount;
    }
    function _isAccountSafe(
        DataTypes.UserInfo storage user,
        uint256 tRate
    ) internal view returns (bool) {
        return user.t0BorrowBalance.decimalMul(tRate) <= _maxMintAmount(user);
    }
    function _isAccountSafeAfterBorrow(
        DataTypes.UserInfo storage user,
        uint256 tRate
    ) internal view returns (bool) {
        return
            user.t0BorrowBalance.decimalMul(tRate) <=
            _maxMintAmountBorrow(user);
    }
    function _maxMintAmount(
        DataTypes.UserInfo storage user
    ) internal view returns (uint256) {
        address[] memory collaterals = user.collateralList;
        uint256 maxMintAmount;
        for (uint256 i; i < collaterals.length; i = i + 1) {
            address collateral = collaterals[i];
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            if (!reserve.isBorrowAllowed) {
                continue;
            }
            maxMintAmount += _getMintAmount(
                user.depositBalance[collateral],
                reserve.oracle,
                reserve.initialMortgageRate
            );
        }
        return maxMintAmount;
    }
    function _maxMintAmountBorrow(
        DataTypes.UserInfo storage user
    ) internal view returns (uint256) {
        address[] memory collaterals = user.collateralList;
        uint256 maxMintAmount;
        for (uint256 i; i < collaterals.length; i = i + 1) {
            address collateral = collaterals[i];
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            if (!reserve.isBorrowAllowed) {
                continue;
            }
            uint256 colMintAmount = _getMintAmountBorrow(
                reserve,
                user.depositBalance[collateral]
            );
            maxMintAmount += colMintAmount;
        }
        return maxMintAmount;
    }
    function _isStartLiquidation(
        DataTypes.UserInfo storage liquidatedTraderInfo,
        uint256 tRate
    ) internal view returns (bool) {
        uint256 JUSDBorrow = (liquidatedTraderInfo.t0BorrowBalance).decimalMul(
            tRate
        );
        uint256 liquidationMaxMintAmount;
        address[] memory collaterals = liquidatedTraderInfo.collateralList;
        for (uint256 i; i < collaterals.length; i = i + 1) {
            address collateral = collaterals[i];
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            if (reserve.isFinalLiquidation) {
                continue;
            }
            liquidationMaxMintAmount += _getMintAmount(
                liquidatedTraderInfo.depositBalance[collateral],
                reserve.oracle,
                reserve.liquidationMortgageRate
            );
        }
        return liquidationMaxMintAmount < JUSDBorrow;
    }
}