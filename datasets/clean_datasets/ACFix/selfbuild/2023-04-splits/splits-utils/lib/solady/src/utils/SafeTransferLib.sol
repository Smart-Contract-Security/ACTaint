pragma solidity ^0.8.4;
library SafeTransferLib {
    error ETHTransferFailed();
    error TransferFromFailed();
    error TransferFailed();
    error ApproveFailed();
    uint256 internal constant _GAS_STIPEND_NO_STORAGE_WRITES = 2300;
    uint256 internal constant _GAS_STIPEND_NO_GRIEF = 100000;
    function safeTransferETH(address to, uint256 amount) internal {
        assembly {
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
        }
    }
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
            if iszero(call(gasStipend, to, amount, 0, 0, 0, 0)) {
                mstore(0x00, to) 
                mstore8(0x0b, 0x73) 
                mstore8(0x20, 0xff) 
                if iszero(create(amount, 0x0b, 0x16)) {
                    if iszero(gt(gas(), 1000000)) { revert(0, 0) }
                }
            }
        }
    }
    function forceSafeTransferETH(address to, uint256 amount) internal {
        assembly {
            if lt(selfbalance(), amount) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
            if iszero(call(_GAS_STIPEND_NO_GRIEF, to, amount, 0, 0, 0, 0)) {
                mstore(0x00, to) 
                mstore8(0x0b, 0x73) 
                mstore8(0x20, 0xff) 
                if iszero(create(amount, 0x0b, 0x16)) {
                    if iszero(gt(gas(), 1000000)) { revert(0, 0) }
                }
            }
        }
    }
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend)
        internal
        returns (bool success)
    {
        assembly {
            success := call(gasStipend, to, amount, 0, 0, 0, 0)
        }
    }
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        assembly {
            let m := mload(0x40) 
            mstore(0x00, 0x23b872dd)
            mstore(0x20, from) 
            mstore(0x40, to) 
            mstore(0x60, amount) 
            if iszero(
                and( 
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) 
            mstore(0x40, m) 
        }
    }
    function safeTransferAllFrom(address token, address from, address to)
        internal
        returns (uint256 amount)
    {
        assembly {
            let m := mload(0x40) 
            mstore(0x00, 0x70a08231) 
            mstore(0x20, from) 
            if iszero(
                and( 
                    gt(returndatasize(), 0x1f), 
                    staticcall(gas(), token, 0x1c, 0x24, 0x60, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x00, 0x23b872dd)
            mstore(0x40, to) 
            amount := mload(0x60)
            if iszero(
                and( 
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x7939f424)
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0) 
            mstore(0x40, m) 
        }
    }
    function safeTransfer(address token, address to, uint256 amount) internal {
        assembly {
            mstore(0x1a, to) 
            mstore(0x3a, amount) 
            mstore(0x00, 0xa9059cbb000000000000)
            if iszero(
                and( 
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x16, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18)
                revert(0x1c, 0x04)
            }
            mstore(0x3a, 0)
        }
    }
    function safeTransferAll(address token, address to) internal returns (uint256 amount) {
        assembly {
            mstore(0x00, 0x70a08231) 
            mstore(0x20, address()) 
            if iszero(
                and( 
                    gt(returndatasize(), 0x1f), 
                    staticcall(gas(), token, 0x1c, 0x24, 0x3a, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18)
                revert(0x1c, 0x04)
            }
            mstore(0x1a, to) 
            amount := mload(0x3a)
            mstore(0x00, 0xa9059cbb000000000000)
            if iszero(
                and( 
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x16, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x90b8ec18)
                revert(0x1c, 0x04)
            }
            mstore(0x3a, 0)
        }
    }
    function safeApprove(address token, address to, uint256 amount) internal {
        assembly {
            mstore(0x1a, to) 
            mstore(0x3a, amount) 
            mstore(0x00, 0x095ea7b3000000000000)
            if iszero(
                and( 
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x16, 0x44, 0x00, 0x20)
                )
            ) {
                mstore(0x00, 0x3e3f8f73)
                revert(0x1c, 0x04)
            }
            mstore(0x3a, 0)
        }
    }
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        assembly {
            mstore(0x00, 0x70a08231) 
            mstore(0x20, account) 
            amount :=
                mul(
                    mload(0x20),
                    and( 
                        gt(returndatasize(), 0x1f), 
                        staticcall(gas(), token, 0x1c, 0x24, 0x20, 0x20)
                    )
                )
        }
    }
}