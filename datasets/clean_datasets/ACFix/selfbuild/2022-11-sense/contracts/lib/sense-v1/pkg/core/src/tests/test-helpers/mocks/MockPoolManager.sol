pragma solidity 0.8.13;
contract MockPoolManager {
    mapping(address => bool) public tInits; 
    mapping(address => mapping(uint256 => bool)) public sInits;
    function deployPool(
        string calldata name,
        bool whitelist,
        uint256 closeFactor,
        uint256 liqIncentive
    ) external returns (uint256 _poolIndex, address _comptroller) {
        return (0, address(1));
    }
    function addTarget(address target) external {
        tInits[target] = true;
    }
    function addSeries(address adapter, uint256 maturity) external {
        sInits[adapter][maturity] = true;
    }
}