pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        _require(address(this).balance >= amount, Errors.ADDRESS_INSUFFICIENT_BALANCE);
        (bool success, ) = recipient.call{ value: amount }("");
        _require(success, Errors.ADDRESS_CANNOT_SEND_VALUE);
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        _require(isContract(target), Errors.CALL_TO_NON_CONTRACT);
        (bool success, bytes memory returndata) = target.call(data);
        return verifyCallResult(success, returndata);
    }
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                _revert(Errors.LOW_LEVEL_CALL_FAILED);
            }
        }
    }
}