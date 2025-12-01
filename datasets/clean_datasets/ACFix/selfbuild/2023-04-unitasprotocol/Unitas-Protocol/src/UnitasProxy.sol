pragma solidity ^0.8.19;
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./Unitas.sol";
contract UnitasProxy is TransparentUpgradeableProxy {
    constructor(
        address logic_,
        address proxyAdmin_,
        Unitas.InitializeConfig memory config_
    ) TransparentUpgradeableProxy(
        logic_,
        proxyAdmin_,
        abi.encodeWithSelector(Unitas.initialize.selector, config_)
    ) {}
}