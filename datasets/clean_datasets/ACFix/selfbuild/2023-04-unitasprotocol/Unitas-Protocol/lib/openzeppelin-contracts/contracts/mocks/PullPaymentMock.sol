pragma solidity ^0.8.0;
import "../security/PullPayment.sol";
contract PullPaymentMock is PullPayment {
    constructor() payable {}
    function callTransfer(address dest, uint256 amount) public {
        _asyncTransfer(dest, amount);
    }
}