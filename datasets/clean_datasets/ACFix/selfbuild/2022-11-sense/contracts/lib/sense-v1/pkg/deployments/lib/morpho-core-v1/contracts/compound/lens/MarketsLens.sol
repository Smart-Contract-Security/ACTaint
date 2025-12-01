pragma solidity 0.8.13;
import "./RatesLens.sol";
abstract contract MarketsLens is RatesLens {
    using CompoundMath for uint256;
    function isMarketCreated(address _poolToken) external view returns (bool) {
        return morpho.marketStatus(_poolToken).isCreated;
    }
    function isMarketCreatedAndNotPaused(address _poolToken) external view returns (bool) {
        Types.MarketStatus memory marketStatus = morpho.marketStatus(_poolToken);
        return marketStatus.isCreated && !marketStatus.isPaused;
    }
    function isMarketCreatedAndNotPausedNorPartiallyPaused(address _poolToken)
        external
        view
        returns (bool)
    {
        Types.MarketStatus memory marketStatus = morpho.marketStatus(_poolToken);
        return marketStatus.isCreated && !marketStatus.isPaused && !marketStatus.isPartiallyPaused;
    }
    function getAllMarkets() external view returns (address[] memory marketsCreated) {
        return morpho.getAllMarkets();
    }
    function getMainMarketData(address _poolToken)
        external
        view
        returns (
            uint256 avgSupplyRatePerBlock,
            uint256 avgBorrowRatePerBlock,
            uint256 p2pSupplyAmount,
            uint256 p2pBorrowAmount,
            uint256 poolSupplyAmount,
            uint256 poolBorrowAmount
        )
    {
        (avgSupplyRatePerBlock, p2pSupplyAmount, poolSupplyAmount) = getAverageSupplyRatePerBlock(
            _poolToken
        );
        (avgBorrowRatePerBlock, p2pBorrowAmount, poolBorrowAmount) = getAverageBorrowRatePerBlock(
            _poolToken
        );
    }
    function getAdvancedMarketData(address _poolToken)
        external
        view
        returns (
            uint256 p2pSupplyIndex,
            uint256 p2pBorrowIndex,
            uint256 poolSupplyIndex,
            uint256 poolBorrowIndex,
            uint32 lastUpdateBlockNumber,
            uint256 p2pSupplyDelta,
            uint256 p2pBorrowDelta
        )
    {
        (p2pSupplyIndex, p2pBorrowIndex, poolSupplyIndex, poolBorrowIndex) = getIndexes(
            _poolToken,
            false
        );
        Types.Delta memory delta = morpho.deltas(_poolToken);
        p2pSupplyDelta = delta.p2pSupplyDelta.mul(poolSupplyIndex);
        p2pBorrowDelta = delta.p2pBorrowDelta.mul(poolBorrowIndex);
        Types.LastPoolIndexes memory lastPoolIndexes = morpho.lastPoolIndexes(_poolToken);
        lastUpdateBlockNumber = lastPoolIndexes.lastUpdateBlockNumber;
    }
    function getMarketConfiguration(address _poolToken)
        external
        view
        returns (
            address underlying,
            bool isCreated,
            bool p2pDisabled,
            bool isPaused,
            bool isPartiallyPaused,
            uint16 reserveFactor,
            uint16 p2pIndexCursor,
            uint256 collateralFactor
        )
    {
        underlying = _poolToken == morpho.cEth() ? morpho.wEth() : ICToken(_poolToken).underlying();
        Types.MarketStatus memory marketStatus = morpho.marketStatus(_poolToken);
        isCreated = marketStatus.isCreated;
        p2pDisabled = morpho.p2pDisabled(_poolToken);
        isPaused = marketStatus.isPaused;
        isPartiallyPaused = marketStatus.isPartiallyPaused;
        Types.MarketParameters memory marketParams = morpho.marketParameters(_poolToken);
        reserveFactor = marketParams.reserveFactor;
        p2pIndexCursor = marketParams.p2pIndexCursor;
        (, collateralFactor, ) = comptroller.markets(_poolToken);
    }
    function getTotalMarketSupply(address _poolToken)
        public
        view
        returns (uint256 p2pSupplyAmount, uint256 poolSupplyAmount)
    {
        (uint256 p2pSupplyIndex, uint256 poolSupplyIndex, ) = _getCurrentP2PSupplyIndex(_poolToken);
        (p2pSupplyAmount, poolSupplyAmount) = _getMarketSupply(
            _poolToken,
            p2pSupplyIndex,
            poolSupplyIndex
        );
    }
    function getTotalMarketBorrow(address _poolToken)
        public
        view
        returns (uint256 p2pBorrowAmount, uint256 poolBorrowAmount)
    {
        (uint256 p2pBorrowIndex, , uint256 poolBorrowIndex) = _getCurrentP2PBorrowIndex(_poolToken);
        (p2pBorrowAmount, poolBorrowAmount) = _getMarketBorrow(
            _poolToken,
            p2pBorrowIndex,
            poolBorrowIndex
        );
    }
}