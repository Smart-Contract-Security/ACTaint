pragma solidity 0.8.13;
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./libraries/CompoundMath.sol";
import "../common/libraries/DelegateCall.sol";
import "./MorphoStorage.sol";
abstract contract MorphoUtils is MorphoStorage {
    using DoubleLinkedList for DoubleLinkedList.List;
    using CompoundMath for uint256;
    using DelegateCall for address;
    error CompoundOracleFailed();
    error MarketNotCreated();
    error MarketPaused();
    modifier isMarketCreated(address _poolTokenAddress) {
        if (!marketStatus[_poolTokenAddress].isCreated) revert MarketNotCreated();
        _;
    }
    modifier isMarketCreatedAndNotPaused(address _poolTokenAddress) {
        Types.MarketStatus memory marketStatus_ = marketStatus[_poolTokenAddress];
        if (!marketStatus_.isCreated) revert MarketNotCreated();
        if (marketStatus_.isPaused) revert MarketPaused();
        _;
    }
    modifier isMarketCreatedAndNotPausedNorPartiallyPaused(address _poolTokenAddress) {
        Types.MarketStatus memory marketStatus_ = marketStatus[_poolTokenAddress];
        if (!marketStatus_.isCreated) revert MarketNotCreated();
        if (marketStatus_.isPaused || marketStatus_.isPartiallyPaused) revert MarketPaused();
        _;
    }
    function getEnteredMarkets(address _user)
        external
        view
        returns (address[] memory enteredMarkets_)
    {
        return enteredMarkets[_user];
    }
    function getAllMarkets() external view returns (address[] memory marketsCreated_) {
        return marketsCreated;
    }
    function getHead(address _poolTokenAddress, Types.PositionType _positionType)
        external
        view
        returns (address head)
    {
        if (_positionType == Types.PositionType.SUPPLIERS_IN_P2P)
            head = suppliersInP2P[_poolTokenAddress].getHead();
        else if (_positionType == Types.PositionType.SUPPLIERS_ON_POOL)
            head = suppliersOnPool[_poolTokenAddress].getHead();
        else if (_positionType == Types.PositionType.BORROWERS_IN_P2P)
            head = borrowersInP2P[_poolTokenAddress].getHead();
        else if (_positionType == Types.PositionType.BORROWERS_ON_POOL)
            head = borrowersOnPool[_poolTokenAddress].getHead();
    }
    function getNext(
        address _poolTokenAddress,
        Types.PositionType _positionType,
        address _user
    ) external view returns (address next) {
        if (_positionType == Types.PositionType.SUPPLIERS_IN_P2P)
            next = suppliersInP2P[_poolTokenAddress].getNext(_user);
        else if (_positionType == Types.PositionType.SUPPLIERS_ON_POOL)
            next = suppliersOnPool[_poolTokenAddress].getNext(_user);
        else if (_positionType == Types.PositionType.BORROWERS_IN_P2P)
            next = borrowersInP2P[_poolTokenAddress].getNext(_user);
        else if (_positionType == Types.PositionType.BORROWERS_ON_POOL)
            next = borrowersOnPool[_poolTokenAddress].getNext(_user);
    }
    function updateP2PIndexes(address _poolTokenAddress)
        external
        isMarketCreated(_poolTokenAddress)
    {
        _updateP2PIndexes(_poolTokenAddress);
    }
    function _updateP2PIndexes(address _poolTokenAddress) internal {
        address(interestRatesManager).functionDelegateCall(
            abi.encodeWithSelector(
                interestRatesManager.updateP2PIndexes.selector,
                _poolTokenAddress
            )
        );
    }
    function _isLiquidatable(
        address _user,
        address _poolTokenAddress,
        uint256 _withdrawnAmount,
        uint256 _borrowedAmount
    ) internal view returns (bool) {
        ICompoundOracle oracle = ICompoundOracle(comptroller.oracle());
        uint256 numberOfEnteredMarkets = enteredMarkets[_user].length;
        Types.AssetLiquidityData memory assetData;
        uint256 maxDebtValue;
        uint256 debtValue;
        uint256 i;
        while (i < numberOfEnteredMarkets) {
            address poolTokenEntered = enteredMarkets[_user][i];
            assetData = _getUserLiquidityDataForAsset(_user, poolTokenEntered, oracle);
            maxDebtValue += assetData.maxDebtValue;
            debtValue += assetData.debtValue;
            if (_poolTokenAddress == poolTokenEntered) {
                if (_borrowedAmount > 0)
                    debtValue += _borrowedAmount.mul(assetData.underlyingPrice);
                if (_withdrawnAmount > 0)
                    maxDebtValue -= _withdrawnAmount.mul(assetData.underlyingPrice).mul(
                        assetData.collateralFactor
                    );
            }
            unchecked {
                ++i;
            }
        }
        return debtValue > maxDebtValue;
    }
    function _getUserLiquidityDataForAsset(
        address _user,
        address _poolTokenAddress,
        ICompoundOracle _oracle
    ) internal view returns (Types.AssetLiquidityData memory assetData) {
        assetData.underlyingPrice = _oracle.getUnderlyingPrice(_poolTokenAddress);
        if (assetData.underlyingPrice == 0) revert CompoundOracleFailed();
        (, assetData.collateralFactor, ) = comptroller.markets(_poolTokenAddress);
        assetData.collateralValue = _getUserSupplyBalanceInOf(_poolTokenAddress, _user).mul(
            assetData.underlyingPrice
        );
        assetData.debtValue = _getUserBorrowBalanceInOf(_poolTokenAddress, _user).mul(
            assetData.underlyingPrice
        );
        assetData.maxDebtValue = assetData.collateralValue.mul(assetData.collateralFactor);
    }
    function _getUserSupplyBalanceInOf(address _poolTokenAddress, address _user)
        internal
        view
        returns (uint256)
    {
        Types.SupplyBalance memory userSupplyBalance = supplyBalanceInOf[_poolTokenAddress][_user];
        return
            userSupplyBalance.inP2P.mul(p2pSupplyIndex[_poolTokenAddress]) +
            userSupplyBalance.onPool.mul(ICToken(_poolTokenAddress).exchangeRateStored());
    }
    function _getUserBorrowBalanceInOf(address _poolTokenAddress, address _user)
        internal
        view
        returns (uint256)
    {
        Types.BorrowBalance memory userBorrowBalance = borrowBalanceInOf[_poolTokenAddress][_user];
        return
            userBorrowBalance.inP2P.mul(p2pBorrowIndex[_poolTokenAddress]) +
            userBorrowBalance.onPool.mul(ICToken(_poolTokenAddress).borrowIndex());
    }
    function _getUnderlying(address _poolTokenAddress) internal view returns (ERC20) {
        if (_poolTokenAddress == cEth)
            return ERC20(wEth);
        else return ERC20(ICToken(_poolTokenAddress).underlying());
    }
}