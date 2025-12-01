pragma solidity 0.8.9;
import "./JOJOView.sol";
import "./JOJOExternal.sol";
import "./JOJOOperation.sol";
contract JOJODealer is JOJOExternal, JOJOOperation, JOJOView {
    constructor(address _primaryAsset) JOJOStorage() {
        state.primaryAsset = _primaryAsset;
    }
    function version() external pure returns (string memory) {
        return "JOJODealer V1.0";
    }
}