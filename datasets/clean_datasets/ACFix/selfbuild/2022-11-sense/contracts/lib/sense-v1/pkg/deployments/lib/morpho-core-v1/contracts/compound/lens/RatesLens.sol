pragma solidity 0.8.13;
import "./UsersLens.sol";
abstract contract RatesLens is UsersLens {
    using CompoundMath for uint256;
    struct Indexes {
        uint256 p2pSupplyIndex;
        uint256 p2pBorrowIndex;
        uint256 poolSupplyIndex;
        uint256 poolBorrowIndex;
    }
    function getNextUserSupplyRatePerBlock(
        address _poolToken,
        address _user,
        uint256 _amount
    )
        external
        view
        returns (
            uint256 nextSupplyRatePerBlock,
            uint256 balanceOnPool,
            uint256 balanceInP2P,
            uint256 totalBalance
        )
    {
        Types.SupplyBalance memory supplyBalance = morpho.supplyBalanceInOf(_poolToken, _user);
        Indexes memory indexes;
        (
            indexes.p2pSupplyIndex,
            indexes.poolSupplyIndex,
            indexes.poolBorrowIndex
        ) = _getCurrentP2PSupplyIndex(_poolToken);
        if (_amount > 0) {
            Types.Delta memory delta = morpho.deltas(_poolToken);
            if (delta.p2pBorrowDelta > 0) {
                uint256 deltaInUnderlying = delta.p2pBorrowDelta.mul(indexes.poolBorrowIndex);
                uint256 matchedDelta = CompoundMath.min(deltaInUnderlying, _amount);
                supplyBalance.inP2P += matchedDelta.div(indexes.p2pSupplyIndex);
                _amount -= matchedDelta;
            }
        }
        if (_amount > 0 && !morpho.p2pDisabled(_poolToken)) {
            uint256 firstPoolBorrowerBalance = morpho
            .borrowBalanceInOf(
                _poolToken,
                morpho.getHead(_poolToken, Types.PositionType.BORROWERS_ON_POOL)
            ).onPool;
            if (firstPoolBorrowerBalance > 0) {
                uint256 borrowerBalanceInUnderlying = firstPoolBorrowerBalance.mul(
                    indexes.poolBorrowIndex
                );
                uint256 matchedP2P = CompoundMath.min(borrowerBalanceInUnderlying, _amount);
                supplyBalance.inP2P += matchedP2P.div(indexes.p2pSupplyIndex);
                _amount -= matchedP2P;
            }
        }
        if (_amount > 0) supplyBalance.onPool += _amount.div(indexes.poolSupplyIndex);
        balanceOnPool = supplyBalance.onPool.mul(indexes.poolSupplyIndex);
        balanceInP2P = supplyBalance.inP2P.mul(indexes.p2pSupplyIndex);
        totalBalance = balanceOnPool + balanceInP2P;
        nextSupplyRatePerBlock = _getUserSupplyRatePerBlock(
            _poolToken,
            balanceOnPool,
            balanceInP2P,
            totalBalance
        );
    }
    function getNextUserBorrowRatePerBlock(
        address _poolToken,
        address _user,
        uint256 _amount
    )
        external
        view
        returns (
            uint256 nextBorrowRatePerBlock,
            uint256 balanceOnPool,
            uint256 balanceInP2P,
            uint256 totalBalance
        )
    {
        Types.BorrowBalance memory borrowBalance = morpho.borrowBalanceInOf(_poolToken, _user);
        Indexes memory indexes;
        (
            indexes.p2pBorrowIndex,
            indexes.poolSupplyIndex,
            indexes.poolBorrowIndex
        ) = _getCurrentP2PBorrowIndex(_poolToken);
        if (_amount > 0) {
            Types.Delta memory delta = morpho.deltas(_poolToken);
            if (delta.p2pSupplyDelta > 0) {
                uint256 deltaInUnderlying = delta.p2pSupplyDelta.mul(indexes.poolSupplyIndex);
                uint256 matchedDelta = CompoundMath.min(deltaInUnderlying, _amount);
                borrowBalance.inP2P += matchedDelta.div(indexes.p2pBorrowIndex);
                _amount -= matchedDelta;
            }
        }
        if (_amount > 0 && !morpho.p2pDisabled(_poolToken)) {
            uint256 firstPoolSupplierBalance = morpho
            .supplyBalanceInOf(
                _poolToken,
                morpho.getHead(_poolToken, Types.PositionType.SUPPLIERS_ON_POOL)
            ).onPool;
            if (firstPoolSupplierBalance > 0) {
                uint256 supplierBalanceInUnderlying = firstPoolSupplierBalance.mul(
                    indexes.poolSupplyIndex
                );
                uint256 matchedP2P = CompoundMath.min(supplierBalanceInUnderlying, _amount);
                borrowBalance.inP2P += matchedP2P.div(indexes.p2pBorrowIndex);
                _amount -= matchedP2P;
            }
        }
        if (_amount > 0) borrowBalance.onPool += _amount.div(indexes.poolBorrowIndex);
        balanceOnPool = borrowBalance.onPool.mul(indexes.poolBorrowIndex);
        balanceInP2P = borrowBalance.inP2P.mul(indexes.p2pBorrowIndex);
        totalBalance = balanceOnPool + balanceInP2P;
        nextBorrowRatePerBlock = _getUserBorrowRatePerBlock(
            _poolToken,
            balanceOnPool,
            balanceInP2P,
            totalBalance
        );
    }
    function getAverageSupplyRatePerBlock(address _poolToken)
        public
        view
        returns (
            uint256 avgSupplyRatePerBlock,
            uint256 p2pSupplyAmount,
            uint256 poolSupplyAmount
        )
    {
        ICToken cToken = ICToken(_poolToken);
        uint256 poolSupplyRate = cToken.supplyRatePerBlock();
        uint256 poolBorrowRate = cToken.borrowRatePerBlock();
        (uint256 p2pSupplyIndex, uint256 poolSupplyIndex, ) = _getCurrentP2PSupplyIndex(_poolToken);
        Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
        uint256 p2pSupplyRate = InterestRatesModel.computeP2PSupplyRatePerBlock(
            InterestRatesModel.P2PRateComputeParams({
                p2pRate: InterestRatesModel.computeRawP2PRatePerBlock(
                    poolSupplyRate,
                    poolBorrowRate,
                    marketParams.p2pIndexCursor
                ),
                poolRate: poolSupplyRate,
                poolIndex: poolSupplyIndex,
                p2pIndex: p2pSupplyIndex,
                p2pDelta: 0,
                p2pAmount: 0,
                reserveFactor: marketParams.reserveFactor
            })
        );
        (p2pSupplyAmount, poolSupplyAmount) = _getMarketSupply(
            _poolToken,
            p2pSupplyIndex,
            poolSupplyIndex
        );
        uint256 totalSupply = p2pSupplyAmount + poolSupplyAmount;
        if (p2pSupplyAmount > 0)
            avgSupplyRatePerBlock += p2pSupplyRate.mul(p2pSupplyAmount.div(totalSupply));
        if (poolSupplyAmount > 0)
            avgSupplyRatePerBlock += poolSupplyRate.mul(poolSupplyAmount.div(totalSupply));
    }
    function getAverageBorrowRatePerBlock(address _poolToken)
        public
        view
        returns (
            uint256 avgBorrowRatePerBlock,
            uint256 p2pBorrowAmount,
            uint256 poolBorrowAmount
        )
    {
        ICToken cToken = ICToken(_poolToken);
        uint256 poolSupplyRate = cToken.supplyRatePerBlock();
        uint256 poolBorrowRate = cToken.borrowRatePerBlock();
        (uint256 p2pBorrowIndex, , uint256 poolBorrowIndex) = _getCurrentP2PBorrowIndex(_poolToken);
        Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
        uint256 p2pBorrowRate = InterestRatesModel.computeP2PBorrowRatePerBlock(
            InterestRatesModel.P2PRateComputeParams({
                p2pRate: InterestRatesModel.computeRawP2PRatePerBlock(
                    poolSupplyRate,
                    poolBorrowRate,
                    marketParams.p2pIndexCursor
                ),
                poolRate: poolBorrowRate,
                poolIndex: poolBorrowIndex,
                p2pIndex: p2pBorrowIndex,
                p2pDelta: 0,
                p2pAmount: 0,
                reserveFactor: marketParams.reserveFactor
            })
        );
        (p2pBorrowAmount, poolBorrowAmount) = _getMarketBorrow(
            _poolToken,
            p2pBorrowIndex,
            poolBorrowIndex
        );
        uint256 totalBorrow = p2pBorrowAmount + poolBorrowAmount;
        if (p2pBorrowAmount > 0)
            avgBorrowRatePerBlock += p2pBorrowRate.mul(p2pBorrowAmount.div(totalBorrow));
        if (poolBorrowAmount > 0)
            avgBorrowRatePerBlock += poolBorrowRate.mul(poolBorrowAmount.div(totalBorrow));
    }
    function getRatesPerBlock(address _poolToken)
        public
        view
        returns (
            uint256 p2pSupplyRate,
            uint256 p2pBorrowRate,
            uint256 poolSupplyRate,
            uint256 poolBorrowRate
        )
    {
        ICToken cToken = ICToken(_poolToken);
        poolSupplyRate = cToken.supplyRatePerBlock();
        poolBorrowRate = cToken.borrowRatePerBlock();
        Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
        uint256 p2pRate = ((MAX_BASIS_POINTS - marketParams.p2pIndexCursor) *
            poolSupplyRate +
            marketParams.p2pIndexCursor *
            poolBorrowRate) / MAX_BASIS_POINTS;
        Types.Delta memory delta = morpho.deltas(_poolToken);
        (
            uint256 p2pSupplyIndex,
            uint256 p2pBorrowIndex,
            uint256 poolSupplyIndex,
            uint256 poolBorrowIndex
        ) = getIndexes(_poolToken, false);
        p2pSupplyRate = InterestRatesModel.computeP2PSupplyRatePerBlock(
            InterestRatesModel.P2PRateComputeParams({
                p2pRate: p2pRate,
                poolRate: poolSupplyRate,
                poolIndex: poolSupplyIndex,
                p2pIndex: p2pSupplyIndex,
                p2pDelta: delta.p2pSupplyDelta,
                p2pAmount: delta.p2pSupplyAmount,
                reserveFactor: marketParams.reserveFactor
            })
        );
        p2pBorrowRate = InterestRatesModel.computeP2PBorrowRatePerBlock(
            InterestRatesModel.P2PRateComputeParams({
                p2pRate: p2pRate,
                poolRate: poolBorrowRate,
                poolIndex: poolBorrowIndex,
                p2pIndex: p2pBorrowIndex,
                p2pDelta: delta.p2pBorrowDelta,
                p2pAmount: delta.p2pBorrowAmount,
                reserveFactor: marketParams.reserveFactor
            })
        );
    }
    function getCurrentUserSupplyRatePerBlock(address _poolToken, address _user)
        public
        view
        returns (uint256)
    {
        (
            uint256 balanceOnPool,
            uint256 balanceInP2P,
            uint256 totalBalance
        ) = getCurrentSupplyBalanceInOf(_poolToken, _user);
        return _getUserSupplyRatePerBlock(_poolToken, balanceOnPool, balanceInP2P, totalBalance);
    }
    function getCurrentUserBorrowRatePerBlock(address _poolToken, address _user)
        public
        view
        returns (uint256)
    {
        (
            uint256 balanceOnPool,
            uint256 balanceInP2P,
            uint256 totalBalance
        ) = getCurrentBorrowBalanceInOf(_poolToken, _user);
        return _getUserBorrowRatePerBlock(_poolToken, balanceOnPool, balanceInP2P, totalBalance);
    }
    function _getMarketSupply(
        address _poolToken,
        uint256 _p2pSupplyIndex,
        uint256 _poolSupplyIndex
    ) internal view returns (uint256 p2pSupplyAmount, uint256 poolSupplyAmount) {
        Types.Delta memory delta = morpho.deltas(_poolToken);
        p2pSupplyAmount =
            delta.p2pSupplyAmount.mul(_p2pSupplyIndex) -
            delta.p2pSupplyDelta.mul(_poolSupplyIndex);
        poolSupplyAmount = ICToken(_poolToken).balanceOf(address(morpho)).mul(_poolSupplyIndex);
    }
    function _getMarketBorrow(
        address _poolToken,
        uint256 _p2pBorrowIndex,
        uint256 _poolBorrowIndex
    ) internal view returns (uint256 p2pBorrowAmount, uint256 poolBorrowAmount) {
        Types.Delta memory delta = morpho.deltas(_poolToken);
        p2pBorrowAmount =
            delta.p2pBorrowAmount.mul(_p2pBorrowIndex) -
            delta.p2pBorrowDelta.mul(_poolBorrowIndex);
        poolBorrowAmount = ICToken(_poolToken)
        .borrowBalanceStored(address(morpho))
        .div(ICToken(_poolToken).borrowIndex())
        .mul(_poolBorrowIndex);
    }
    function _getUserSupplyRatePerBlock(
        address _poolToken,
        uint256 _balanceOnPool,
        uint256 _balanceInP2P,
        uint256 _totalBalance
    ) internal view returns (uint256 supplyRatePerBlock_) {
        if (_totalBalance == 0) return 0;
        (uint256 p2pSupplyRate, , uint256 poolSupplyRate, ) = getRatesPerBlock(_poolToken);
        if (_balanceOnPool > 0)
            supplyRatePerBlock_ += poolSupplyRate.mul(_balanceOnPool.div(_totalBalance));
        if (_balanceInP2P > 0)
            supplyRatePerBlock_ += p2pSupplyRate.mul(_balanceInP2P.div(_totalBalance));
    }
    function _getUserBorrowRatePerBlock(
        address _poolToken,
        uint256 _balanceOnPool,
        uint256 _balanceInP2P,
        uint256 _totalBalance
    ) internal view returns (uint256 borrowRatePerBlock_) {
        if (_totalBalance == 0) return 0;
        (, uint256 p2pBorrowRate, , uint256 poolBorrowRate) = getRatesPerBlock(_poolToken);
        if (_balanceOnPool > 0)
            borrowRatePerBlock_ += poolBorrowRate.mul(_balanceOnPool.div(_totalBalance));
        if (_balanceInP2P > 0)
            borrowRatePerBlock_ += p2pBorrowRate.mul(_balanceInP2P.div(_totalBalance));
    }
}