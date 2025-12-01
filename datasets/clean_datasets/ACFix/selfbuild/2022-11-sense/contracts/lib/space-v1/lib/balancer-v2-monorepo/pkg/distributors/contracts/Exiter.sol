pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IBasePool.sol";
import "@balancer-labs/v2-pool-weighted/contracts/BaseWeightedPool.sol";
import "./PoolTokenCache.sol";
import "./interfaces/IDistributorCallback.sol";
contract Exiter is PoolTokenCache, IDistributorCallback {
    constructor(IVault _vault) PoolTokenCache(_vault) {
    }
    struct CallbackParams {
        address[] pools;
        address payable recipient;
    }
    function distributorCallback(bytes calldata callbackData) external override {
        CallbackParams memory params = abi.decode(callbackData, (CallbackParams));
        for (uint256 p; p < params.pools.length; p++) {
            address poolAddress = params.pools[p];
            IBasePool poolContract = IBasePool(poolAddress);
            bytes32 poolId = poolContract.getPoolId();
            ensurePoolTokenSetSaved(poolId);
            IERC20 pool = IERC20(poolAddress);
            _exitPool(pool, poolId, params.recipient);
        }
    }
    function _exitPool(
        IERC20 pool,
        bytes32 poolId,
        address payable recipient
    ) internal {
        IAsset[] memory assets = _getAssets(poolId);
        uint256[] memory minAmountsOut = new uint256[](assets.length);
        uint256 bptAmountIn = pool.balanceOf(address(this));
        bytes memory userData = abi.encode(BaseWeightedPool.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, bptAmountIn);
        bool toInternalBalance = false;
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(
            assets,
            minAmountsOut,
            userData,
            toInternalBalance
        );
        vault.exitPool(poolId, address(this), recipient, request);
    }
}