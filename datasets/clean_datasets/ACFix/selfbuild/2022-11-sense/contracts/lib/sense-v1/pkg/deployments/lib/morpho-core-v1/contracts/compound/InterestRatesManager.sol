pragma solidity 0.8.13;
import "./interfaces/IInterestRatesManager.sol";
import "./libraries/CompoundMath.sol";
import "./MorphoStorage.sol";
contract InterestRatesManager is IInterestRatesManager, MorphoStorage {
    using CompoundMath for uint256;
    struct Params {
        uint256 lastP2PSupplyIndex; 
        uint256 lastP2PBorrowIndex; 
        uint256 poolSupplyIndex; 
        uint256 poolBorrowIndex; 
        uint256 lastPoolSupplyIndex; 
        uint256 lastPoolBorrowIndex; 
        uint256 reserveFactor; 
        uint256 p2pIndexCursor; 
        Types.Delta delta; 
    }
    event P2PIndexesUpdated(
        address indexed _poolTokenAddress,
        uint256 _p2pSupplyIndex,
        uint256 _p2pBorrowIndex,
        uint256 _poolSupplyIndex,
        uint256 _poolBorrowIndex
    );
    function updateP2PIndexes(address _poolTokenAddress) external {
        Types.LastPoolIndexes storage poolIndexes = lastPoolIndexes[_poolTokenAddress];
        if (block.number > poolIndexes.lastUpdateBlockNumber) {
            Types.MarketParameters storage marketParams = marketParameters[_poolTokenAddress];
            uint256 poolSupplyIndex = ICToken(_poolTokenAddress).exchangeRateCurrent();
            uint256 poolBorrowIndex = ICToken(_poolTokenAddress).borrowIndex();
            Params memory params = Params(
                p2pSupplyIndex[_poolTokenAddress],
                p2pBorrowIndex[_poolTokenAddress],
                poolSupplyIndex,
                poolBorrowIndex,
                poolIndexes.lastSupplyPoolIndex,
                poolIndexes.lastBorrowPoolIndex,
                marketParams.reserveFactor,
                marketParams.p2pIndexCursor,
                deltas[_poolTokenAddress]
            );
            (uint256 newP2PSupplyIndex, uint256 newP2PBorrowIndex) = _computeP2PIndexes(params);
            p2pSupplyIndex[_poolTokenAddress] = newP2PSupplyIndex;
            p2pBorrowIndex[_poolTokenAddress] = newP2PBorrowIndex;
            poolIndexes.lastUpdateBlockNumber = uint32(block.number);
            poolIndexes.lastSupplyPoolIndex = uint112(poolSupplyIndex);
            poolIndexes.lastBorrowPoolIndex = uint112(poolBorrowIndex);
            emit P2PIndexesUpdated(
                _poolTokenAddress,
                newP2PSupplyIndex,
                newP2PBorrowIndex,
                poolSupplyIndex,
                poolBorrowIndex
            );
        }
    }
    function _computeP2PIndexes(Params memory _params)
        internal
        pure
        returns (uint256 newP2PSupplyIndex, uint256 newP2PBorrowIndex)
    {
        uint256 poolSupplyGrowthFactor = _params.poolSupplyIndex.div(_params.lastPoolSupplyIndex);
        uint256 poolBorrowGrowthFactor = _params.poolBorrowIndex.div(_params.lastPoolBorrowIndex);
        uint256 p2pSupplyGrowthFactor;
        uint256 p2pBorrowGrowthFactor;
        if (poolSupplyGrowthFactor <= poolBorrowGrowthFactor) {
            uint256 p2pGrowthFactor = ((MAX_BASIS_POINTS - _params.p2pIndexCursor) *
                poolSupplyGrowthFactor +
                _params.p2pIndexCursor *
                poolBorrowGrowthFactor) / MAX_BASIS_POINTS;
            p2pSupplyGrowthFactor =
                p2pGrowthFactor -
                (_params.reserveFactor * (p2pGrowthFactor - poolSupplyGrowthFactor)) /
                MAX_BASIS_POINTS;
            p2pBorrowGrowthFactor =
                p2pGrowthFactor +
                (_params.reserveFactor * (poolBorrowGrowthFactor - p2pGrowthFactor)) /
                MAX_BASIS_POINTS;
        } else {
            p2pSupplyGrowthFactor = poolBorrowGrowthFactor;
            p2pBorrowGrowthFactor = poolBorrowGrowthFactor;
        }
        if (_params.delta.p2pSupplyAmount == 0 || _params.delta.p2pSupplyDelta == 0) {
            newP2PSupplyIndex = _params.lastP2PSupplyIndex.mul(p2pSupplyGrowthFactor);
        } else {
            uint256 shareOfTheDelta = CompoundMath.min(
                (_params.delta.p2pSupplyDelta.mul(_params.lastPoolSupplyIndex)).div(
                    (_params.delta.p2pSupplyAmount).mul(_params.lastP2PSupplyIndex)
                ),
                WAD 
            );
            newP2PSupplyIndex = _params.lastP2PSupplyIndex.mul(
                (WAD - shareOfTheDelta).mul(p2pSupplyGrowthFactor) +
                    shareOfTheDelta.mul(poolSupplyGrowthFactor)
            );
        }
        if (_params.delta.p2pBorrowAmount == 0 || _params.delta.p2pBorrowDelta == 0) {
            newP2PBorrowIndex = _params.lastP2PBorrowIndex.mul(p2pBorrowGrowthFactor);
        } else {
            uint256 shareOfTheDelta = CompoundMath.min(
                (_params.delta.p2pBorrowDelta.mul(_params.lastPoolBorrowIndex)).div(
                    (_params.delta.p2pBorrowAmount).mul(_params.lastP2PBorrowIndex)
                ),
                WAD 
            );
            newP2PBorrowIndex = _params.lastP2PBorrowIndex.mul(
                (WAD - shareOfTheDelta).mul(p2pBorrowGrowthFactor) +
                    shareOfTheDelta.mul(poolBorrowGrowthFactor)
            );
        }
    }
}