pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "../factories/BasePoolFactory.sol";
import "./MockFactoryCreatedPool.sol";
contract MockPoolFactory is BasePoolFactory {
    constructor(IVault _vault) BasePoolFactory(_vault) {
    }
    function create() external returns (address) {
        address pool = address(new MockFactoryCreatedPool());
        _register(pool);
        return pool;
    }
}