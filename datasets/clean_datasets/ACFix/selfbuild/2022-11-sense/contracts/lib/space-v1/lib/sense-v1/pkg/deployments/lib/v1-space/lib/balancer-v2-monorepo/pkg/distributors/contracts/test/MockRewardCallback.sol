pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "../interfaces/IDistributorCallback.sol";
contract MockRewardCallback is IDistributorCallback {
    event CallbackReceived();
    function distributorCallback(bytes calldata) external override {
        emit CallbackReceived();
        return;
    }
}