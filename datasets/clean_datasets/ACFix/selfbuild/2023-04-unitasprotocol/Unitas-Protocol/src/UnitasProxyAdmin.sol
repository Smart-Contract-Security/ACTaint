pragma solidity ^0.8.19;
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
contract UnitasProxyAdmin is ProxyAdmin {
    constructor(address owner_) {
        if (owner_ != owner()) {
            _transferOwnership(owner_);
        }
    }
}