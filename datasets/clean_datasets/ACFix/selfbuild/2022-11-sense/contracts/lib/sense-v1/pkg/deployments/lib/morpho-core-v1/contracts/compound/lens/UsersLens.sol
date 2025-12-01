pragma solidity 0.8.13;
import "./IndexesLens.sol";
abstract contract UsersLens is IndexesLens {
    using CompoundMath for uint256;
    error CompoundOracleFailed();
    function getEnteredMarkets(address _user)
        external
        view
        returns (address[] memory enteredMarkets)
    {
        return morpho.getEnteredMarkets(_user);
    }
    function getUserMaxCapacitiesForAsset(address _user, address _poolToken)
        external
        view
        returns (uint256 withdrawable, uint256 borrowable)
    {
        Types.LiquidityData memory data;
        Types.AssetLiquidityData memory assetData;
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        address[] memory enteredMarkets = morpho.getEnteredMarkets(_user);
        uint256 nbEnteredMarkets = enteredMarkets.length;
        for (uint256 i; i < nbEnteredMarkets; ) {
            address poolTokenEntered = enteredMarkets[i];
            if (_poolToken != poolTokenEntered) {
                assetData = getUserLiquidityDataForAsset(_user, poolTokenEntered, false, oracle);
                data.maxDebtValue += assetData.maxDebtValue;
                data.debtValue += assetData.debtValue;
            }
            unchecked {
                ++i;
            }
        }
        assetData = getUserLiquidityDataForAsset(_user, _poolToken, true, oracle);
        data.maxDebtValue += assetData.maxDebtValue;
        data.debtValue += assetData.debtValue;
        if (data.maxDebtValue < data.debtValue) return (0, 0);
        borrowable = (data.maxDebtValue - data.debtValue).div(assetData.underlyingPrice);
        withdrawable = assetData.collateralValue.div(assetData.underlyingPrice);
        if (assetData.collateralFactor != 0) {
            withdrawable = CompoundMath.min(
                withdrawable,
                borrowable.div(assetData.collateralFactor)
            );
        }
    }
    function computeLiquidationRepayAmount(
        address _user,
        address _poolTokenBorrowed,
        address _poolTokenCollateral,
        address[] calldata _updatedMarkets
    ) external view returns (uint256 toRepay) {
        address[] memory updatedMarkets = new address[](_updatedMarkets.length + 2);
        uint256 nbUpdatedMarkets = _updatedMarkets.length;
        for (uint256 i; i < nbUpdatedMarkets; ) {
            updatedMarkets[i] = _updatedMarkets[i];
            unchecked {
                ++i;
            }
        }
        updatedMarkets[updatedMarkets.length - 2] = _poolTokenBorrowed;
        updatedMarkets[updatedMarkets.length - 1] = _poolTokenCollateral;
        if (!isLiquidatable(_user, updatedMarkets)) return 0;
        ICompoundOracle compoundOracle = ICompoundOracle(comptroller.oracle());
        (, , uint256 totalCollateralBalance) = getCurrentSupplyBalanceInOf(
            _poolTokenCollateral,
            _user
        );
        (, , uint256 totalBorrowBalance) = getCurrentBorrowBalanceInOf(_poolTokenBorrowed, _user);
        uint256 borrowedPrice = compoundOracle.getUnderlyingPrice(_poolTokenBorrowed);
        uint256 collateralPrice = compoundOracle.getUnderlyingPrice(_poolTokenCollateral);
        if (borrowedPrice == 0 || collateralPrice == 0) revert CompoundOracleFailed();
        uint256 maxROIRepay = totalCollateralBalance.mul(collateralPrice).div(borrowedPrice).div(
            comptroller.liquidationIncentiveMantissa()
        );
        uint256 maxRepayable = totalBorrowBalance.mul(comptroller.closeFactorMantissa());
        toRepay = maxROIRepay > maxRepayable ? maxRepayable : maxROIRepay;
    }
    function getUserHealthFactor(address _user, address[] calldata _updatedMarkets)
        external
        view
        returns (uint256)
    {
        (, uint256 debtValue, uint256 maxDebtValue) = getUserBalanceStates(_user, _updatedMarkets);
        if (debtValue == 0) return type(uint256).max;
        return maxDebtValue.div(debtValue);
    }
    function getUserBalanceStates(address _user, address[] calldata _updatedMarkets)
        public
        view
        returns (
            uint256 collateralValue,
            uint256 debtValue,
            uint256 maxDebtValue
        )
    {
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        address[] memory enteredMarkets = morpho.getEnteredMarkets(_user);
        uint256 nbEnteredMarkets = enteredMarkets.length;
        uint256 nbUpdatedMarkets = _updatedMarkets.length;
        for (uint256 i; i < nbEnteredMarkets; ) {
            address poolTokenEntered = enteredMarkets[i];
            bool shouldUpdateIndexes;
            for (uint256 j; j < nbUpdatedMarkets; ) {
                if (_updatedMarkets[j] == poolTokenEntered) {
                    shouldUpdateIndexes = true;
                    break;
                }
                unchecked {
                    ++j;
                }
            }
            Types.AssetLiquidityData memory assetData = getUserLiquidityDataForAsset(
                _user,
                poolTokenEntered,
                shouldUpdateIndexes,
                oracle
            );
            collateralValue += assetData.collateralValue;
            maxDebtValue += assetData.maxDebtValue;
            debtValue += assetData.debtValue;
            unchecked {
                ++i;
            }
        }
    }
    function getCurrentSupplyBalanceInOf(address _poolToken, address _user)
        public
        view
        returns (
            uint256 balanceOnPool,
            uint256 balanceInP2P,
            uint256 totalBalance
        )
    {
        (uint256 p2pSupplyIndex, uint256 poolSupplyIndex, ) = _getCurrentP2PSupplyIndex(_poolToken);
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(_poolToken, _user);
        balanceOnPool = supplyBalance.onPool.mul(poolSupplyIndex);
        balanceInP2P = supplyBalance.inP2P.mul(p2pSupplyIndex);
        totalBalance = balanceOnPool + balanceInP2P;
    }
    function getCurrentBorrowBalanceInOf(address _poolToken, address _user)
        public
        view
        returns (
            uint256 balanceOnPool,
            uint256 balanceInP2P,
            uint256 totalBalance
        )
    {
        (uint256 p2pBorrowIndex, , uint256 poolBorrowIndex) = _getCurrentP2PBorrowIndex(_poolToken);
        Types.BorrowBalance memory borrowBalance = morpho.borrowBalanceInOf(_poolToken, _user);
        balanceOnPool = borrowBalance.onPool.mul(poolBorrowIndex);
        balanceInP2P = borrowBalance.inP2P.mul(p2pBorrowIndex);
        totalBalance = balanceOnPool + balanceInP2P;
    }
    function getUserHypotheticalBalanceStates(
        address _user,
        address _poolToken,
        uint256 _withdrawnAmount,
        uint256 _borrowedAmount
    ) public view returns (uint256 debtValue, uint256 maxDebtValue) {
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        address[] memory enteredMarkets = morpho.getEnteredMarkets(_user);
        uint256 nbEnteredMarkets = enteredMarkets.length;
        for (uint256 i; i < nbEnteredMarkets; ) {
            address poolTokenEntered = enteredMarkets[i];
            Types.AssetLiquidityData memory assetData = getUserLiquidityDataForAsset(
                _user,
                poolTokenEntered,
                true,
                oracle
            );
            maxDebtValue += assetData.maxDebtValue;
            debtValue += assetData.debtValue;
            unchecked {
                ++i;
            }
            if (_poolToken == poolTokenEntered) {
                if (_borrowedAmount > 0)
                    debtValue += _borrowedAmount.mul(assetData.underlyingPrice);
                if (_withdrawnAmount > 0)
                    maxDebtValue -= _withdrawnAmount.mul(assetData.underlyingPrice).mul(
                        assetData.collateralFactor
                    );
            }
        }
    }
    function getUserLiquidityDataForAsset(
        address _user,
        address _poolToken,
        bool _getUpdatedIndexes,
        ICompoundOracle _oracle
    ) public view returns (Types.AssetLiquidityData memory assetData) {
        assetData.underlyingPrice = _oracle.getUnderlyingPrice(_poolToken);
        if (assetData.underlyingPrice == 0) revert CompoundOracleFailed();
        (, assetData.collateralFactor, ) = comptroller.markets(_poolToken);
        (
            uint256 p2pSupplyIndex,
            uint256 p2pBorrowIndex,
            uint256 poolSupplyIndex,
            uint256 poolBorrowIndex
        ) = getIndexes(_poolToken, _getUpdatedIndexes);
        assetData.collateralValue = _getUserSupplyBalanceInOf(
            _poolToken,
            _user,
            p2pSupplyIndex,
            poolSupplyIndex
        ).mul(assetData.underlyingPrice);
        assetData.debtValue = _getUserBorrowBalanceInOf(
            _poolToken,
            _user,
            p2pBorrowIndex,
            poolBorrowIndex
        ).mul(assetData.underlyingPrice);
        assetData.maxDebtValue = assetData.collateralValue.mul(assetData.collateralFactor);
    }
    function isLiquidatable(address _user, address[] memory _updatedMarkets)
        public
        view
        returns (bool)
    {
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        address[] memory enteredMarkets = morpho.getEnteredMarkets(_user);
        uint256 maxDebtValue;
        uint256 debtValue;
        uint256 nbEnteredMarkets = enteredMarkets.length;
        uint256 nbUpdatedMarkets = _updatedMarkets.length;
        for (uint256 i; i < nbEnteredMarkets; ) {
            address poolTokenEntered = enteredMarkets[i];
            bool shouldUpdateIndexes;
            for (uint256 j; j < nbUpdatedMarkets; ) {
                if (_updatedMarkets[j] == poolTokenEntered) {
                    shouldUpdateIndexes = true;
                    break;
                }
                unchecked {
                    ++j;
                }
            }
            Types.AssetLiquidityData memory assetData = getUserLiquidityDataForAsset(
                _user,
                poolTokenEntered,
                shouldUpdateIndexes,
                oracle
            );
            maxDebtValue += assetData.maxDebtValue;
            debtValue += assetData.debtValue;
            unchecked {
                ++i;
            }
        }
        return debtValue > maxDebtValue;
    }
    function _getUserSupplyBalanceInOf(
        address _poolToken,
        address _user,
        uint256 _p2pSupplyIndex,
        uint256 _poolSupplyIndex
    ) internal view returns (uint256) {
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(_poolToken, _user);
        return
            supplyBalance.inP2P.mul(_p2pSupplyIndex) + supplyBalance.onPool.mul(_poolSupplyIndex);
    }
    function _getUserBorrowBalanceInOf(
        address _poolToken,
        address _user,
        uint256 _p2pBorrowIndex,
        uint256 _poolBorrowIndex
    ) internal view returns (uint256) {
        Types.BorrowBalance memory borrowBalance = morpho.borrowBalanceInOf(_poolToken, _user);
        return
            borrowBalance.inP2P.mul(_p2pBorrowIndex) + borrowBalance.onPool.mul(_poolBorrowIndex);
    }
}