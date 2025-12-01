pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "../interfaces/IRateProvider.sol";
contract MockRateProvider is IRateProvider {
    uint256 internal _rate;
    constructor() {
        _rate = FixedPoint.ONE;
    }
    function getRate() external view override returns (uint256) {
        return _rate;
    }
    function mockRate(uint256 newRate) external {
        _rate = newRate;
    }
}