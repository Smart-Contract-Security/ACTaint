pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
import "./IERC20.sol";
library SafeERC20 {
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(address(token), abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(address(token), abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function _callOptionalReturn(address token, bytes memory data) private {
        (bool success, bytes memory returndata) = token.call(data);
        assembly {
            if eq(success, 0) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        _require(returndata.length == 0 || abi.decode(returndata, (bool)), Errors.SAFE_ERC20_CALL_FAILED);
    }
}