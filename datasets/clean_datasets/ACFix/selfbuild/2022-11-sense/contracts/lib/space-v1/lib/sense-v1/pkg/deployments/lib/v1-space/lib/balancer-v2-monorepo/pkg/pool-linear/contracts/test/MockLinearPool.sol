pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./MockLinearMath.sol";
import "../LinearPool.sol";
contract MockLinearPool is LinearPool, MockLinearMath {
    constructor(NewPoolParams memory params) LinearPool(params) {
    }
    function getScalingFactor(IERC20 token) external view returns (uint256) {
        return _scalingFactor(token);
    }
    function mockCacheWrappedTokenRateIfNecessary() external {
        _cacheWrappedTokenRateIfNecessary();
    }
}