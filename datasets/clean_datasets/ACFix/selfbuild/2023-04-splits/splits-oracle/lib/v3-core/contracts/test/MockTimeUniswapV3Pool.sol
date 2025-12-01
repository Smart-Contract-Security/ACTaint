pragma solidity =0.8.12;
import {UniswapV3Pool} from '../UniswapV3Pool.sol';
contract MockTimeUniswapV3Pool is UniswapV3Pool {
    uint256 public time = 1601906400;
    function setFeeGrowthGlobal0X128(uint256 _feeGrowthGlobal0X128) external {
        feeGrowthGlobal0X128 = _feeGrowthGlobal0X128;
    }
    function setFeeGrowthGlobal1X128(uint256 _feeGrowthGlobal1X128) external {
        feeGrowthGlobal1X128 = _feeGrowthGlobal1X128;
    }
    function advanceTime(uint256 by) external {
        time += by;
    }
    function _blockTimestamp() internal view override returns (uint32) {
        return uint32(time);
    }
}