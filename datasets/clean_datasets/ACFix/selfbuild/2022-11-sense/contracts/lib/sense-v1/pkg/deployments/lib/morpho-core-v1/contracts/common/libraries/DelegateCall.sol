pragma solidity ^0.8.0;
library DelegateCall {
    error LowLevelDelegateCallFailed();
    function functionDelegateCall(address _target, bytes memory _data)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returndata) = _target.delegatecall(_data);
        if (success) return returndata;
        else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else revert LowLevelDelegateCallFailed();
        }
    }
}