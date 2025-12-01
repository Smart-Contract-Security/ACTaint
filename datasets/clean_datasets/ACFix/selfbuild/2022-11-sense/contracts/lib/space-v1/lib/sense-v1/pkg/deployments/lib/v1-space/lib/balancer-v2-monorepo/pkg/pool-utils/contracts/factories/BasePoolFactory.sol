pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
abstract contract BasePoolFactory {
    IVault private immutable _vault;
    mapping(address => bool) private _isPoolFromFactory;
    event PoolCreated(address indexed pool);
    constructor(IVault vault) {
        _vault = vault;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function isPoolFromFactory(address pool) external view returns (bool) {
        return _isPoolFromFactory[pool];
    }
    function _register(address pool) internal {
        _isPoolFromFactory[pool] = true;
        emit PoolCreated(pool);
    }
}