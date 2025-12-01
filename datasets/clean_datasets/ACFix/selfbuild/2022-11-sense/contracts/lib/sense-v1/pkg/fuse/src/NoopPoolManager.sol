pragma solidity 0.8.13;
contract NoopPoolManager {
    function deployPool(
        string calldata name,
        uint256 closeFactor,
        uint256 liqIncentive,
        address fallbackOracle
    ) external returns (uint256 _poolIndex, address _comptroller) {}
    function addTarget(address target, address adapter) external returns (address cTarget) {}
    function queueSeries(
        address adapter,
        uint256 maturity,
        address pool
    ) external {}
    function addSeries(address adapter, uint256 maturity) external returns (address, address) {}
}