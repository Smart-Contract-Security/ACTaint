pragma solidity >=0.6.0;
import {IERC20Minimal} from '../interfaces/IERC20Minimal.sol';
library TransferHelper {
    error TF();
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value)
        );
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TF();
    }
}