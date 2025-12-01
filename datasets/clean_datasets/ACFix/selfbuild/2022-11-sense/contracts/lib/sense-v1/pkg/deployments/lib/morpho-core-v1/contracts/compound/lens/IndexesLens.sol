pragma solidity 0.8.13;
import "../libraries/InterestRatesModel.sol";
import "./LensStorage.sol";
abstract contract IndexesLens is LensStorage {
    using CompoundMath for uint256;
    function getCurrentP2PSupplyIndex(address _poolToken)
        public
        view
        returns (uint256 currentP2PSupplyIndex)
    {
        (currentP2PSupplyIndex, , ) = _getCurrentP2PSupplyIndex(_poolToken);
    }
    function getCurrentP2PBorrowIndex(address _poolToken)
        public
        view
        returns (uint256 currentP2PBorrowIndex)
    {
        (currentP2PBorrowIndex, , ) = _getCurrentP2PBorrowIndex(_poolToken);
    }
    function getIndexes(address _poolToken, bool _getUpdatedIndexes)
        public
        view
        returns (
            uint256 newP2PSupplyIndex,
            uint256 newP2PBorrowIndex,
            uint256 newPoolSupplyIndex,
            uint256 newPoolBorrowIndex
        )
    {
        if (!_getUpdatedIndexes) {
            ICToken cToken = ICToken(_poolToken);
            newPoolSupplyIndex = cToken.exchangeRateStored();
            newPoolBorrowIndex = cToken.borrowIndex();
        } else {
            (newPoolSupplyIndex, newPoolBorrowIndex) = getCurrentPoolIndexes(_poolToken);
        }
        Types.LastPoolIndexes memory lastPoolIndexes = morpho.lastPoolIndexes(_poolToken);
        if (!_getUpdatedIndexes || block.number == lastPoolIndexes.lastUpdateBlockNumber) {
            newP2PSupplyIndex = morpho.p2pSupplyIndex(_poolToken);
            newP2PBorrowIndex = morpho.p2pBorrowIndex(_poolToken);
        } else {
            Types.Delta memory delta = morpho.deltas(_poolToken);
            Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
            InterestRatesModel.GrowthFactors memory growthFactors = InterestRatesModel
            .computeGrowthFactors(
                newPoolSupplyIndex,
                newPoolBorrowIndex,
                lastPoolIndexes,
                marketParams.p2pIndexCursor,
                marketParams.reserveFactor
            );
            newP2PSupplyIndex = InterestRatesModel.computeP2PSupplyIndex(
                InterestRatesModel.P2PSupplyIndexComputeParams({
                    poolSupplyGrowthFactor: growthFactors.poolSupplyGrowthFactor,
                    p2pSupplyGrowthFactor: growthFactors.p2pSupplyGrowthFactor,
                    lastPoolSupplyIndex: lastPoolIndexes.lastSupplyPoolIndex,
                    lastP2PSupplyIndex: morpho.p2pSupplyIndex(_poolToken),
                    p2pSupplyDelta: delta.p2pSupplyDelta,
                    p2pSupplyAmount: delta.p2pSupplyAmount
                })
            );
            newP2PBorrowIndex = InterestRatesModel.computeP2PBorrowIndex(
                InterestRatesModel.P2PBorrowIndexComputeParams({
                    poolBorrowGrowthFactor: growthFactors.poolBorrowGrowthFactor,
                    p2pBorrowGrowthFactor: growthFactors.p2pBorrowGrowthFactor,
                    lastPoolBorrowIndex: lastPoolIndexes.lastBorrowPoolIndex,
                    lastP2PBorrowIndex: morpho.p2pBorrowIndex(_poolToken),
                    p2pBorrowDelta: delta.p2pBorrowDelta,
                    p2pBorrowAmount: delta.p2pBorrowAmount
                })
            );
        }
    }
    function getCurrentPoolIndexes(address _poolToken)
        public
        view
        returns (uint256 currentPoolSupplyIndex, uint256 currentPoolBorrowIndex)
    {
        ICToken cToken = ICToken(_poolToken);
        uint256 accrualBlockNumberPrior = cToken.accrualBlockNumber();
        if (block.number == accrualBlockNumberPrior)
            return (cToken.exchangeRateStored(), cToken.borrowIndex());
        uint256 cashPrior = cToken.getCash();
        uint256 totalSupply = cToken.totalSupply();
        uint256 borrowsPrior = cToken.totalBorrows();
        uint256 reservesPrior = cToken.totalReserves();
        uint256 borrowIndexPrior = cToken.borrowIndex();
        uint256 borrowRateMantissa = cToken.borrowRatePerBlock();
        require(borrowRateMantissa <= 0.0005e16, "borrow rate is absurdly high");
        uint256 blockDelta = block.number - accrualBlockNumberPrior;
        uint256 simpleInterestFactor = borrowRateMantissa * blockDelta;
        uint256 interestAccumulated = simpleInterestFactor.mul(borrowsPrior);
        uint256 totalBorrowsNew = interestAccumulated + borrowsPrior;
        uint256 totalReservesNew = cToken.reserveFactorMantissa().mul(interestAccumulated) +
            reservesPrior;
        currentPoolSupplyIndex = totalSupply > 0
            ? (cashPrior + totalBorrowsNew - totalReservesNew).div(totalSupply)
            : cToken.initialExchangeRateMantissa();
        currentPoolBorrowIndex = simpleInterestFactor.mul(borrowIndexPrior) + borrowIndexPrior;
    }
    function _getCurrentP2PSupplyIndex(address _poolToken)
        internal
        view
        returns (
            uint256 currentP2PSupplyIndex,
            uint256 currentPoolSupplyIndex,
            uint256 currentPoolBorrowIndex
        )
    {
        (currentPoolSupplyIndex, currentPoolBorrowIndex) = getCurrentPoolIndexes(_poolToken);
        Types.LastPoolIndexes memory lastPoolIndexes = morpho.lastPoolIndexes(_poolToken);
        if (block.number == lastPoolIndexes.lastUpdateBlockNumber)
            currentP2PSupplyIndex = morpho.p2pSupplyIndex(_poolToken);
        else {
            Types.Delta memory delta = morpho.deltas(_poolToken);
            Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
            InterestRatesModel.GrowthFactors memory growthFactors = InterestRatesModel
            .computeGrowthFactors(
                currentPoolSupplyIndex,
                currentPoolBorrowIndex,
                lastPoolIndexes,
                marketParams.p2pIndexCursor,
                marketParams.reserveFactor
            );
            currentP2PSupplyIndex = InterestRatesModel.computeP2PSupplyIndex(
                InterestRatesModel.P2PSupplyIndexComputeParams({
                    poolSupplyGrowthFactor: growthFactors.poolSupplyGrowthFactor,
                    p2pSupplyGrowthFactor: growthFactors.p2pSupplyGrowthFactor,
                    lastPoolSupplyIndex: lastPoolIndexes.lastSupplyPoolIndex,
                    lastP2PSupplyIndex: morpho.p2pSupplyIndex(_poolToken),
                    p2pSupplyDelta: delta.p2pSupplyDelta,
                    p2pSupplyAmount: delta.p2pSupplyAmount
                })
            );
        }
    }
    function _getCurrentP2PBorrowIndex(address _poolToken)
        internal
        view
        returns (
            uint256 currentP2PBorrowIndex,
            uint256 currentPoolSupplyIndex,
            uint256 currentPoolBorrowIndex
        )
    {
        (currentPoolSupplyIndex, currentPoolBorrowIndex) = getCurrentPoolIndexes(_poolToken);
        Types.LastPoolIndexes memory lastPoolIndexes = morpho.lastPoolIndexes(_poolToken);
        if (block.number == lastPoolIndexes.lastUpdateBlockNumber)
            currentP2PBorrowIndex = morpho.p2pBorrowIndex(_poolToken);
        else {
            Types.Delta memory delta = morpho.deltas(_poolToken);
            Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
            InterestRatesModel.GrowthFactors memory growthFactors = InterestRatesModel
            .computeGrowthFactors(
                currentPoolSupplyIndex,
                currentPoolBorrowIndex,
                lastPoolIndexes,
                marketParams.p2pIndexCursor,
                marketParams.reserveFactor
            );
            currentP2PBorrowIndex = InterestRatesModel.computeP2PBorrowIndex(
                InterestRatesModel.P2PBorrowIndexComputeParams({
                    poolBorrowGrowthFactor: growthFactors.poolBorrowGrowthFactor,
                    p2pBorrowGrowthFactor: growthFactors.p2pBorrowGrowthFactor,
                    lastPoolBorrowIndex: lastPoolIndexes.lastBorrowPoolIndex,
                    lastP2PBorrowIndex: morpho.p2pBorrowIndex(_poolToken),
                    p2pBorrowDelta: delta.p2pBorrowDelta,
                    p2pBorrowAmount: delta.p2pBorrowAmount
                })
            );
        }
    }
}