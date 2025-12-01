pragma solidity ^0.8.0;
import "./CompoundMath.sol";
import "./Types.sol";
library InterestRatesModel {
    using CompoundMath for uint256;
    uint256 public constant MAX_BASIS_POINTS = 10_000; 
    uint256 public constant WAD = 1e18;
    struct GrowthFactors {
        uint256 poolSupplyGrowthFactor; 
        uint256 poolBorrowGrowthFactor; 
        uint256 p2pSupplyGrowthFactor; 
        uint256 p2pBorrowGrowthFactor; 
    }
    struct P2PSupplyIndexComputeParams {
        uint256 poolSupplyGrowthFactor; 
        uint256 p2pSupplyGrowthFactor; 
        uint256 lastP2PSupplyIndex; 
        uint256 lastPoolSupplyIndex; 
        uint256 p2pSupplyDelta; 
        uint256 p2pSupplyAmount; 
    }
    struct P2PBorrowIndexComputeParams {
        uint256 poolBorrowGrowthFactor; 
        uint256 p2pBorrowGrowthFactor; 
        uint256 lastP2PBorrowIndex; 
        uint256 lastPoolBorrowIndex; 
        uint256 p2pBorrowDelta; 
        uint256 p2pBorrowAmount; 
    }
    struct P2PRateComputeParams {
        uint256 poolRate; 
        uint256 p2pRate; 
        uint256 poolIndex; 
        uint256 p2pIndex; 
        uint256 p2pDelta; 
        uint256 p2pAmount; 
        uint16 reserveFactor; 
    }
    function computeGrowthFactors(
        uint256 _newPoolSupplyIndex,
        uint256 _newPoolBorrowIndex,
        Types.LastPoolIndexes memory _lastPoolIndexes,
        uint16 _p2pIndexCursor,
        uint256 _reserveFactor
    ) internal pure returns (GrowthFactors memory growthFactors_) {
        growthFactors_.poolSupplyGrowthFactor = _newPoolSupplyIndex.div(
            _lastPoolIndexes.lastSupplyPoolIndex
        );
        growthFactors_.poolBorrowGrowthFactor = _newPoolBorrowIndex.div(
            _lastPoolIndexes.lastBorrowPoolIndex
        );
        if (growthFactors_.poolSupplyGrowthFactor <= growthFactors_.poolBorrowGrowthFactor) {
            uint256 p2pGrowthFactor = ((MAX_BASIS_POINTS - _p2pIndexCursor) *
                growthFactors_.poolSupplyGrowthFactor +
                _p2pIndexCursor *
                growthFactors_.poolBorrowGrowthFactor) / MAX_BASIS_POINTS;
            growthFactors_.p2pSupplyGrowthFactor =
                p2pGrowthFactor -
                (_reserveFactor * (p2pGrowthFactor - growthFactors_.poolSupplyGrowthFactor)) /
                MAX_BASIS_POINTS;
            growthFactors_.p2pBorrowGrowthFactor =
                p2pGrowthFactor +
                (_reserveFactor * (growthFactors_.poolBorrowGrowthFactor - p2pGrowthFactor)) /
                MAX_BASIS_POINTS;
        } else {
            growthFactors_.p2pSupplyGrowthFactor = growthFactors_.poolBorrowGrowthFactor;
            growthFactors_.p2pBorrowGrowthFactor = growthFactors_.poolBorrowGrowthFactor;
        }
    }
    function computeP2PSupplyIndex(P2PSupplyIndexComputeParams memory _params)
        internal
        pure
        returns (uint256 newP2PSupplyIndex_)
    {
        if (_params.p2pSupplyAmount == 0 || _params.p2pSupplyDelta == 0) {
            newP2PSupplyIndex_ = _params.lastP2PSupplyIndex.mul(_params.p2pSupplyGrowthFactor);
        } else {
            uint256 shareOfTheDelta = CompoundMath.min(
                (_params.p2pSupplyDelta.mul(_params.lastPoolSupplyIndex)).div(
                    (_params.p2pSupplyAmount).mul(_params.lastP2PSupplyIndex)
                ),
                WAD 
            );
            newP2PSupplyIndex_ = _params.lastP2PSupplyIndex.mul(
                (WAD - shareOfTheDelta).mul(_params.p2pSupplyGrowthFactor) +
                    shareOfTheDelta.mul(_params.poolSupplyGrowthFactor)
            );
        }
    }
    function computeP2PBorrowIndex(P2PBorrowIndexComputeParams memory _params)
        internal
        pure
        returns (uint256 newP2PBorrowIndex_)
    {
        if (_params.p2pBorrowAmount == 0 || _params.p2pBorrowDelta == 0) {
            newP2PBorrowIndex_ = _params.lastP2PBorrowIndex.mul(_params.p2pBorrowGrowthFactor);
        } else {
            uint256 shareOfTheDelta = CompoundMath.min(
                (_params.p2pBorrowDelta.mul(_params.lastPoolBorrowIndex)).div(
                    (_params.p2pBorrowAmount).mul(_params.lastP2PBorrowIndex)
                ),
                WAD 
            );
            newP2PBorrowIndex_ = _params.lastP2PBorrowIndex.mul(
                (WAD - shareOfTheDelta).mul(_params.p2pBorrowGrowthFactor) +
                    shareOfTheDelta.mul(_params.poolBorrowGrowthFactor)
            );
        }
    }
    function computeRawP2PRatePerBlock(
        uint256 _poolSupplyRate,
        uint256 _poolBorrowRate,
        uint256 _p2pIndexCursor
    ) internal pure returns (uint256) {
        return
            ((MAX_BASIS_POINTS - _p2pIndexCursor) *
                _poolSupplyRate +
                _p2pIndexCursor *
                _poolBorrowRate) / MAX_BASIS_POINTS;
    }
    function computeP2PSupplyRatePerBlock(P2PRateComputeParams memory _params)
        internal
        pure
        returns (uint256 p2pSupplyRate)
    {
        p2pSupplyRate =
            _params.p2pRate -
            ((_params.p2pRate - _params.poolRate) * _params.reserveFactor) /
            MAX_BASIS_POINTS;
        if (_params.p2pDelta > 0 && _params.p2pAmount > 0) {
            uint256 shareOfTheDelta = CompoundMath.min(
                (_params.p2pDelta.mul(_params.poolIndex)).div(
                    (_params.p2pAmount).mul(_params.p2pIndex)
                ),
                WAD 
            );
            p2pSupplyRate =
                p2pSupplyRate.mul(WAD - shareOfTheDelta) +
                _params.poolRate.mul(shareOfTheDelta);
        }
    }
    function computeP2PBorrowRatePerBlock(P2PRateComputeParams memory _params)
        internal
        pure
        returns (uint256 p2pBorrowRate)
    {
        p2pBorrowRate =
            _params.p2pRate +
            ((_params.poolRate - _params.p2pRate) * _params.reserveFactor) /
            MAX_BASIS_POINTS;
        if (_params.p2pDelta > 0 && _params.p2pAmount > 0) {
            uint256 shareOfTheDelta = CompoundMath.min(
                (_params.p2pDelta.mul(_params.poolIndex)).div(
                    (_params.p2pAmount).mul(_params.p2pIndex)
                ),
                WAD 
            );
            p2pBorrowRate =
                p2pBorrowRate.mul(WAD - shareOfTheDelta) +
                _params.poolRate.mul(shareOfTheDelta);
        }
    }
}