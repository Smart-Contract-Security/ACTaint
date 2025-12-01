pragma solidity =0.8.15;
import '../interfaces/IPeripheryImmutableState.sol';
abstract contract PeripheryImmutableState is IPeripheryImmutableState {
    address public immutable override factory;
    address public immutable override WETH9;
    constructor(address _factory, address _WETH9) {
        factory = _factory;
        WETH9 = _WETH9;
    }
}