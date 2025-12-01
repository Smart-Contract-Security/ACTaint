pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "../factories/BasePoolSplitCodeFactory.sol";
import "./MockFactoryCreatedPool.sol";
contract MockPoolSplitCodeFactory is BasePoolSplitCodeFactory {
    constructor(IVault _vault) BasePoolSplitCodeFactory(_vault, type(MockFactoryCreatedPool).creationCode) {
    }
    function create() external returns (address) {
        return _create("");
    }
}