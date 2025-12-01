pragma solidity ^0.8.4;
abstract contract ERC721 {
    uint256 internal constant _MAX_ACCOUNT_BALANCE = 0xffffffff;
    error NotOwnerNorApproved();
    error TokenDoesNotExist();
    error TokenAlreadyExists();
    error BalanceQueryForZeroAddress();
    error TransferToZeroAddress();
    error TransferFromIncorrectOwner();
    error AccountBalanceOverflow();
    error TransferToNonERC721ReceiverImplementer();
    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed account, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool isApproved);
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint256 private constant _APPROVAL_EVENT_SIGNATURE =
        0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925;
    uint256 private constant _APPROVAL_FOR_ALL_EVENT_SIGNATURE =
        0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31;
    uint256 private constant _ERC721_MASTER_SLOT_SEED = 0x7d8825530a5a2e7a << 192;
    function name() public view virtual returns (string memory);
    function symbol() public view virtual returns (string memory);
    function tokenURI(uint256 id) public view virtual returns (string memory);
    function ownerOf(uint256 id) public view virtual returns (address result) {
        result = _ownerOf(id);
        assembly {
            if iszero(result) {
                mstore(0x00, 0xceea21b6) 
                revert(0x1c, 0x04)
            }
        }
    }
    function balanceOf(address owner) public view virtual returns (uint256 result) {
        assembly {
            if iszero(owner) {
                mstore(0x00, 0x8f4eb604) 
                revert(0x1c, 0x04)
            }
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            mstore(0x00, owner)
            result := and(sload(keccak256(0x0c, 0x1c)), _MAX_ACCOUNT_BALANCE)
        }
    }
    function getApproved(uint256 id) public view virtual returns (address result) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            if iszero(shr(96, shl(96, sload(ownershipSlot)))) {
                mstore(0x00, 0xceea21b6) 
                revert(0x1c, 0x04)
            }
            result := sload(add(1, ownershipSlot))
        }
    }
    function approve(address account, uint256 id) public payable virtual {
        _approve(msg.sender, account, id);
    }
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        returns (bool result)
    {
        assembly {
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, shr(96, shl(96, operator))))
            mstore(0x00, owner)
            result := sload(keccak256(0x0c, 0x30))
        }
    }
    function setApprovalForAll(address operator, bool isApproved) public virtual {
        assembly {
            operator := shr(96, shl(96, operator))
            isApproved := iszero(iszero(isApproved))
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, operator))
            mstore(0x00, caller())
            sstore(keccak256(0x0c, 0x30), isApproved)
            mstore(0x00, isApproved)
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, caller(), operator)
        }
    }
    function transferFrom(address from, address to, uint256 id) public payable virtual {
        _beforeTokenTransfer(from, to, id);
        assembly {
            let bitmaskAddress := shr(96, not(0))
            from := and(bitmaskAddress, from)
            to := and(bitmaskAddress, to)
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, caller()))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            let owner := and(bitmaskAddress, ownershipPacked)
            if iszero(mul(owner, eq(owner, from))) {
                if iszero(owner) {
                    mstore(0x00, 0xceea21b6) 
                    revert(0x1c, 0x04)
                }
                mstore(0x00, 0xa1148100) 
                revert(0x1c, 0x04)
            }
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            {
                mstore(0x00, from)
                let approvedAddress := sload(add(1, ownershipSlot))
                if iszero(or(eq(caller(), from), eq(caller(), approvedAddress))) {
                    if iszero(sload(keccak256(0x0c, 0x30))) {
                        mstore(0x00, 0x4b6e7f18) 
                        revert(0x1c, 0x04)
                    }
                }
                if approvedAddress { sstore(add(1, ownershipSlot), 0) }
            }
            sstore(ownershipSlot, xor(ownershipPacked, xor(from, to)))
            {
                let fromBalanceSlot := keccak256(0x0c, 0x1c)
                sstore(fromBalanceSlot, sub(sload(fromBalanceSlot), 1))
            }
            {
                mstore(0x00, to)
                let toBalanceSlot := keccak256(0x0c, 0x1c)
                let toBalanceSlotPacked := add(sload(toBalanceSlot), 1)
                if iszero(and(toBalanceSlotPacked, _MAX_ACCOUNT_BALANCE)) {
                    mstore(0x00, 0x01336cea) 
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceSlotPacked)
            }
            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, from, to, id)
        }
        _afterTokenTransfer(from, to, id);
    }
    function safeTransferFrom(address from, address to, uint256 id) public payable virtual {
        transferFrom(from, to, id);
        if (_hasCode(to)) _checkOnERC721Received(from, to, id, "");
    }
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data)
        public
        payable
        virtual
    {
        transferFrom(from, to, id);
        if (_hasCode(to)) _checkOnERC721Received(from, to, id, data);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        assembly {
            let s := shr(224, interfaceId)
            result := or(or(eq(s, 0x01ffc9a7), eq(s, 0x80ac58cd)), eq(s, 0x5b5e139f))
        }
    }
    function _exists(uint256 id) internal view virtual returns (bool result) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            result := shl(96, sload(add(id, add(id, keccak256(0x00, 0x20)))))
        }
    }
    function _ownerOf(uint256 id) internal view virtual returns (address result) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            result := shr(96, shl(96, sload(add(id, add(id, keccak256(0x00, 0x20))))))
        }
    }
    function _getAux(address owner) internal view virtual returns (uint224 result) {
        assembly {
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            mstore(0x00, owner)
            result := shr(32, sload(keccak256(0x0c, 0x1c)))
        }
    }
    function _setAux(address owner, uint224 value) internal virtual {
        assembly {
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            mstore(0x00, owner)
            let balanceSlot := keccak256(0x0c, 0x1c)
            let packed := sload(balanceSlot)
            sstore(balanceSlot, xor(packed, shl(32, xor(value, shr(32, packed)))))
        }
    }
    function _getExtraData(uint256 id) internal view virtual returns (uint96 result) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            result := shr(160, sload(add(id, add(id, keccak256(0x00, 0x20)))))
        }
    }
    function _setExtraData(uint256 id, uint96 value) internal virtual {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let packed := sload(ownershipSlot)
            sstore(ownershipSlot, xor(packed, shl(160, xor(value, shr(160, packed)))))
        }
    }
    function _mint(address to, uint256 id) internal virtual {
        _beforeTokenTransfer(address(0), to, id);
        assembly {
            to := shr(96, shl(96, to))
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            if shl(96, ownershipPacked) {
                mstore(0x00, 0xc991cbb1) 
                revert(0x1c, 0x04)
            }
            sstore(ownershipSlot, or(ownershipPacked, to))
            {
                mstore(0x00, to)
                let balanceSlot := keccak256(0x0c, 0x1c)
                let balanceSlotPacked := add(sload(balanceSlot), 1)
                if iszero(and(balanceSlotPacked, _MAX_ACCOUNT_BALANCE)) {
                    mstore(0x00, 0x01336cea) 
                    revert(0x1c, 0x04)
                }
                sstore(balanceSlot, balanceSlotPacked)
            }
            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, 0, to, id)
        }
        _afterTokenTransfer(address(0), to, id);
    }
    function _safeMint(address to, uint256 id) internal virtual {
        _safeMint(to, id, "");
    }
    function _safeMint(address to, uint256 id, bytes memory data) internal virtual {
        _mint(to, id);
        if (_hasCode(to)) _checkOnERC721Received(address(0), to, id, data);
    }
    function _burn(uint256 id) internal virtual {
        _burn(address(0), id);
    }
    function _burn(address by, uint256 id) internal virtual {
        address owner = ownerOf(id);
        _beforeTokenTransfer(owner, address(0), id);
        assembly {
            by := shr(96, shl(96, by))
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, by))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            owner := shr(96, shl(96, ownershipPacked))
            if iszero(owner) {
                mstore(0x00, 0xceea21b6) 
                revert(0x1c, 0x04)
            }
            {
                mstore(0x00, owner)
                let approvedAddress := sload(add(1, ownershipSlot))
                if iszero(or(iszero(by), or(eq(by, owner), eq(by, approvedAddress)))) {
                    if iszero(sload(keccak256(0x0c, 0x30))) {
                        mstore(0x00, 0x4b6e7f18) 
                        revert(0x1c, 0x04)
                    }
                }
                if approvedAddress { sstore(add(1, ownershipSlot), 0) }
            }
            sstore(ownershipSlot, xor(ownershipPacked, owner))
            {
                let balanceSlot := keccak256(0x0c, 0x1c)
                sstore(balanceSlot, sub(sload(balanceSlot), 1))
            }
            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, owner, 0, id)
        }
        _afterTokenTransfer(owner, address(0), id);
    }
    function _isApprovedOrOwner(address account, uint256 id)
        internal
        view
        virtual
        returns (bool result)
    {
        assembly {
            result := 1
            account := shr(96, shl(96, account))
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, account))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let owner := shr(96, shl(96, sload(ownershipSlot)))
            if iszero(owner) {
                mstore(0x00, 0xceea21b6) 
                revert(0x1c, 0x04)
            }
            if iszero(eq(account, owner)) {
                mstore(0x00, owner)
                if iszero(sload(keccak256(0x0c, 0x30))) {
                    result := eq(account, sload(add(1, ownershipSlot)))
                }
            }
        }
    }
    function _getApproved(uint256 id) internal view virtual returns (address result) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            result := sload(add(1, add(id, add(id, keccak256(0x00, 0x20)))))
        }
    }
    function _approve(address account, uint256 id) internal virtual {
        _approve(address(0), account, id);
    }
    function _approve(address by, address account, uint256 id) internal virtual {
        assembly {
            let bitmaskAddress := shr(96, not(0))
            account := and(bitmaskAddress, account)
            by := and(bitmaskAddress, by)
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, by))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let owner := and(bitmaskAddress, sload(ownershipSlot))
            if iszero(owner) {
                mstore(0x00, 0xceea21b6) 
                revert(0x1c, 0x04)
            }
            if iszero(or(iszero(by), eq(by, owner))) {
                mstore(0x00, owner)
                if iszero(sload(keccak256(0x0c, 0x30))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            sstore(add(1, ownershipSlot), account)
            log4(0x00, 0x00, _APPROVAL_EVENT_SIGNATURE, owner, account, id)
        }
    }
    function _setApprovalForAll(address by, address operator, bool isApproved) internal virtual {
        assembly {
            by := shr(96, shl(96, by))
            operator := shr(96, shl(96, operator))
            isApproved := iszero(iszero(isApproved))
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, operator))
            mstore(0x00, by)
            sstore(keccak256(0x0c, 0x30), isApproved)
            mstore(0x00, isApproved)
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, by, operator)
        }
    }
    function _transfer(address from, address to, uint256 id) internal virtual {
        _transfer(address(0), from, to, id);
    }
    function _transfer(address by, address from, address to, uint256 id) internal virtual {
        _beforeTokenTransfer(from, to, id);
        assembly {
            let bitmaskAddress := shr(96, not(0))
            from := and(bitmaskAddress, from)
            to := and(bitmaskAddress, to)
            by := and(bitmaskAddress, by)
            mstore(0x00, id)
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, by))
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            let owner := and(bitmaskAddress, ownershipPacked)
            if iszero(mul(owner, eq(owner, from))) {
                if iszero(owner) {
                    mstore(0x00, 0xceea21b6) 
                    revert(0x1c, 0x04)
                }
                mstore(0x00, 0xa1148100) 
                revert(0x1c, 0x04)
            }
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            {
                mstore(0x00, from)
                let approvedAddress := sload(add(1, ownershipSlot))
                if iszero(or(iszero(by), or(eq(by, from), eq(by, approvedAddress)))) {
                    if iszero(sload(keccak256(0x0c, 0x30))) {
                        mstore(0x00, 0x4b6e7f18) 
                        revert(0x1c, 0x04)
                    }
                }
                if approvedAddress { sstore(add(1, ownershipSlot), 0) }
            }
            sstore(ownershipSlot, xor(ownershipPacked, xor(from, to)))
            {
                let fromBalanceSlot := keccak256(0x0c, 0x1c)
                sstore(fromBalanceSlot, sub(sload(fromBalanceSlot), 1))
            }
            {
                mstore(0x00, to)
                let toBalanceSlot := keccak256(0x0c, 0x1c)
                let toBalanceSlotPacked := add(sload(toBalanceSlot), 1)
                if iszero(and(toBalanceSlotPacked, _MAX_ACCOUNT_BALANCE)) {
                    mstore(0x00, 0x01336cea) 
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceSlotPacked)
            }
            log4(0x00, 0x00, _TRANSFER_EVENT_SIGNATURE, from, to, id)
        }
        _afterTokenTransfer(from, to, id);
    }
    function _safeTransfer(address from, address to, uint256 id) internal virtual {
        _safeTransfer(from, to, id, "");
    }
    function _safeTransfer(address from, address to, uint256 id, bytes memory data)
        internal
        virtual
    {
        _transfer(address(0), from, to, id);
        if (_hasCode(to)) _checkOnERC721Received(from, to, id, data);
    }
    function _safeTransfer(address by, address from, address to, uint256 id) internal virtual {
        _safeTransfer(by, from, to, id, "");
    }
    function _safeTransfer(address by, address from, address to, uint256 id, bytes memory data)
        internal
        virtual
    {
        _transfer(by, from, to, id);
        if (_hasCode(to)) _checkOnERC721Received(from, to, id, data);
    }
    function _beforeTokenTransfer(address from, address to, uint256 id) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 id) internal virtual {}
    function _hasCode(address a) private view returns (bool result) {
        assembly {
            result := extcodesize(a) 
        }
    }
    function _checkOnERC721Received(address from, address to, uint256 id, bytes memory data)
        private
    {
        assembly {
            let m := mload(0x40)
            let onERC721ReceivedSelector := 0x150b7a02
            mstore(m, onERC721ReceivedSelector)
            mstore(add(m, 0x20), caller()) 
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            mstore(add(m, 0x60), id)
            mstore(add(m, 0x80), 0x80)
            let n := mload(data)
            mstore(add(m, 0xa0), n)
            if n { pop(staticcall(gas(), 4, add(data, 0x20), n, add(m, 0xc0), n)) }
            if iszero(call(gas(), to, 0, add(m, 0x1c), add(n, 0xa4), m, 0x20)) {
                if returndatasize() {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(m, 0)
            }
            if iszero(eq(mload(m), shl(224, onERC721ReceivedSelector))) {
                mstore(0x00, 0xd1a57ed6) 
                revert(0x1c, 0x04)
            }
        }
    }
}