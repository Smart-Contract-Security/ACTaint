pragma solidity ^0.8.4;
abstract contract Ownable {
    error Unauthorized();
    error NewOwnerIsZeroAddress();
    error NoHandoverRequest();
    uint256 private constant _UNAUTHORIZED_ERROR_SELECTOR = 0x82b42900;
    uint256 private constant _NEW_OWNER_IS_ZERO_ADDRESS_ERROR_SELECTOR = 0x7448fbae;
    uint256 private constant _NO_HANDOVER_REQUEST_ERROR_SELECTOR = 0x6f5e8818;
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event OwnershipHandoverRequested(address indexed pendingOwner);
    event OwnershipHandoverCanceled(address indexed pendingOwner);
    uint256 private constant _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;
    uint256 private constant _OWNERSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE =
        0xdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d;
    uint256 private constant _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE =
        0xfa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c92;
    uint256 private constant _OWNER_SLOT_NOT = 0x8b78c6d8;
    uint256 private constant _HANDOVER_SLOT_SEED = 0x389a75e1;
    function _initializeOwner(address newOwner) internal virtual {
        assembly {
            newOwner := shr(96, shl(96, newOwner))
            sstore(not(_OWNER_SLOT_NOT), newOwner)
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, 0, newOwner)
        }
    }
    function _setOwner(address newOwner) internal virtual {
        assembly {
            let ownerSlot := not(_OWNER_SLOT_NOT)
            newOwner := shr(96, shl(96, newOwner))
            log3(0, 0, _OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(ownerSlot), newOwner)
            sstore(ownerSlot, newOwner)
        }
    }
    function _checkOwner() internal view virtual {
        assembly {
            if iszero(eq(caller(), sload(not(_OWNER_SLOT_NOT)))) {
                mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
    }
    function transferOwnership(address newOwner) public payable virtual onlyOwner {
        assembly {
            if iszero(shl(96, newOwner)) {
                mstore(0x00, _NEW_OWNER_IS_ZERO_ADDRESS_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        _setOwner(newOwner);
    }
    function renounceOwnership() public payable virtual onlyOwner {
        _setOwner(address(0));
    }
    function requestOwnershipHandover() public payable virtual {
        unchecked {
            uint256 expires = block.timestamp + ownershipHandoverValidFor();
            assembly {
                mstore(0x0c, _HANDOVER_SLOT_SEED)
                mstore(0x00, caller())
                sstore(keccak256(0x0c, 0x20), expires)
                log2(0, 0, _OWNERSHIP_HANDOVER_REQUESTED_EVENT_SIGNATURE, caller())
            }
        }
    }
    function cancelOwnershipHandover() public payable virtual {
        assembly {
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, caller())
            sstore(keccak256(0x0c, 0x20), 0)
            log2(0, 0, _OWNERSHIP_HANDOVER_CANCELED_EVENT_SIGNATURE, caller())
        }
    }
    function completeOwnershipHandover(address pendingOwner) public payable virtual onlyOwner {
        assembly {
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            let handoverSlot := keccak256(0x0c, 0x20)
            if gt(timestamp(), sload(handoverSlot)) {
                mstore(0x00, _NO_HANDOVER_REQUEST_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            sstore(handoverSlot, 0)
        }
        _setOwner(pendingOwner);
    }
    function owner() public view virtual returns (address result) {
        assembly {
            result := sload(not(_OWNER_SLOT_NOT))
        }
    }
    function ownershipHandoverExpiresAt(address pendingOwner)
        public
        view
        virtual
        returns (uint256 result)
    {
        assembly {
            mstore(0x0c, _HANDOVER_SLOT_SEED)
            mstore(0x00, pendingOwner)
            result := sload(keccak256(0x0c, 0x20))
        }
    }
    function ownershipHandoverValidFor() public view virtual returns (uint64) {
        return 48 * 3600;
    }
    modifier onlyOwner() virtual {
        _checkOwner();
        _;
    }
}