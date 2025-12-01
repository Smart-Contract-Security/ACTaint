pragma solidity >=0.7.5;
pragma abicoder v2;
import './IMulticall.sol';
import './ISelfPermit.sol';
import './IPoolInitializer.sol';
interface IV3Migrator is IMulticall, ISelfPermit, IPoolInitializer {
    struct MigrateParams {
        address pair; 
        uint256 liquidityToMigrate; 
        uint8 percentageToMigrate; 
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Min; 
        uint256 amount1Min; 
        address recipient;
        uint256 deadline;
        bool refundAsETH;
    }
    function migrate(MigrateParams calldata params) external;
}