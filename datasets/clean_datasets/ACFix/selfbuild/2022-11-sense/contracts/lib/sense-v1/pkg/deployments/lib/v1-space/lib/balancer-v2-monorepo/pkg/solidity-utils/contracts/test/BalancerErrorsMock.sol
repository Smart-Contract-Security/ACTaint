pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
contract BalancerErrorsMock {
    function fail(uint256 code) external pure {
        _revert(code);
    }
}