pragma solidity ^0.8.0;
library Types {
    enum PositionType {
        SUPPLIERS_IN_P2P,
        SUPPLIERS_ON_POOL,
        BORROWERS_IN_P2P,
        BORROWERS_ON_POOL
    }
    struct SupplyBalance {
        uint256 inP2P; 
        uint256 onPool; 
    }
    struct BorrowBalance {
        uint256 inP2P; 
        uint256 onPool; 
    }
    struct MaxGasForMatching {
        uint64 supply;
        uint64 borrow;
        uint64 withdraw;
        uint64 repay;
    }
    struct Delta {
        uint256 p2pSupplyDelta; 
        uint256 p2pBorrowDelta; 
        uint256 p2pSupplyAmount; 
        uint256 p2pBorrowAmount; 
    }
    struct AssetLiquidityData {
        uint256 collateralValue; 
        uint256 maxDebtValue; 
        uint256 debtValue; 
        uint256 underlyingPrice; 
        uint256 collateralFactor; 
    }
    struct LiquidityData {
        uint256 collateralValue; 
        uint256 maxDebtValue; 
        uint256 debtValue; 
    }
    struct LastPoolIndexes {
        uint32 lastUpdateBlockNumber; 
        uint112 lastSupplyPoolIndex; 
        uint112 lastBorrowPoolIndex; 
    }
    struct MarketParameters {
        uint16 reserveFactor; 
        uint16 p2pIndexCursor; 
    }
    struct MarketStatus {
        bool isCreated; 
        bool isPaused; 
        bool isPartiallyPaused; 
    }
}