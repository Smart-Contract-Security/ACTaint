pragma solidity ^0.8.19;
import "./Errors.sol";
library AddressUtils {
    function checkContract(address account) internal view {
        checkNotZero(account);
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        _require(size > 0, Errors.ADDRESS_CODE_SIZE_ZERO);
    }
    function checkNotZero(address account) internal pure {
        _require(account != address(0), Errors.ADDRESS_ZERO);
    }
}