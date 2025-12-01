pragma solidity >=0.8.0;
import {ERC20} from "../tokens/ERC20.sol";
library SafeTransferLib {
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;
        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
        require(success, "ETH_TRANSFER_FAILED");
    }
    function safeTransferFrom(
        ERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;
        assembly {
            let memPointer := mload(0x40)
            mstore(0, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(4, from) 
            mstore(36, to) 
            mstore(68, amount) 
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, 0, 100, 0, 32)
            )
            mstore(0x60, 0) 
            mstore(0x40, memPointer) 
        }
        require(success, "TRANSFER_FROM_FAILED");
    }
    function safeTransfer(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;
        assembly {
            let memPointer := mload(0x40)
            mstore(0, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(4, to) 
            mstore(36, amount) 
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, 0, 68, 0, 32)
            )
            mstore(0x60, 0) 
            mstore(0x40, memPointer) 
        }
        require(success, "TRANSFER_FAILED");
    }
    function safeApprove(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;
        assembly {
            let memPointer := mload(0x40)
            mstore(0, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(4, to) 
            mstore(36, amount) 
            success := and(
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                call(gas(), token, 0, 0, 68, 0, 32)
            )
            mstore(0x60, 0) 
            mstore(0x40, memPointer) 
        }
        require(success, "APPROVE_FAILED");
    }
}