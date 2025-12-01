pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BaseSplitCodeFactory.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
abstract contract BasePoolSplitCodeFactory is BaseSplitCodeFactory {
    IVault private immutable _vault;
    mapping(address => bool) private _isPoolFromFactory;
    event PoolCreated(address indexed pool);
    constructor(IVault vault, bytes memory creationCode) BaseSplitCodeFactory(creationCode) {
        _vault = vault;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function isPoolFromFactory(address pool) external view returns (bool) {
        return _isPoolFromFactory[pool];
    }
    function _create(bytes memory constructorArgs) internal override returns (address) {
        address pool = super._create(constructorArgs);
        _isPoolFromFactory[pool] = true;
        emit PoolCreated(pool);
        return pool;
    }
}