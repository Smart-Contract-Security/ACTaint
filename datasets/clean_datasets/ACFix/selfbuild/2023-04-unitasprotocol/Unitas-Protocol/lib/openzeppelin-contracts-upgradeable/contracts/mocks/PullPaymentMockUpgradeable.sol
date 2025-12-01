pragma solidity ^0.8.0;
import "../security/PullPaymentUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
contract PullPaymentMockUpgradeable is Initializable, PullPaymentUpgradeable {
    function __PullPaymentMock_init() internal onlyInitializing {
        __PullPayment_init_unchained();
    }
    function __PullPaymentMock_init_unchained() internal onlyInitializing {}
    function callTransfer(address dest, uint256 amount) public {
        _asyncTransfer(dest, amount);
    }
    uint256[50] private __gap;
}