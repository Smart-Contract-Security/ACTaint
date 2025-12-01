pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/test/MockPool.sol";
import "../IAssetManager.sol";
contract MockAssetManagedPool is MockPool {
    constructor(IVault vault, IVault.PoolSpecialization specialization) MockPool(vault, specialization) {
    }
    function setAssetManagerPoolConfig(address assetManager, bytes memory poolConfig) public {
        IAssetManager(assetManager).setConfig(getPoolId(), poolConfig);
    }
}