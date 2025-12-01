pragma solidity ^0.8.4;
abstract contract ERC1155 {
    error ArrayLengthsMismatch();
    error TransferToZeroAddress();
    error AccountBalanceOverflow();
    error InsufficientBalance();
    error NotOwnerNorApproved();
    error TransferToNonERC1155ReceiverImplementer();
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );
    event ApprovalForAll(address indexed owner, address indexed operator, bool isApproved);
    event URI(string value, uint256 indexed id);
    uint256 private constant _TRANSFER_SINGLE_EVENT_SIGNATURE =
        0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;
    uint256 private constant _TRANSFER_BATCH_EVENT_SIGNATURE =
        0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb;
    uint256 private constant _APPROVAL_FOR_ALL_EVENT_SIGNATURE =
        0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31;
    uint256 private constant _ERC1155_MASTER_SLOT_SEED = 0x9a31110384e0b0c9;
    function uri(uint256 id) public view virtual returns (string memory);
    function balanceOf(address owner, uint256 id) public view virtual returns (uint256 result) {
        assembly {
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, shl(96, owner)))
            mstore(0x00, id)
            result := sload(keccak256(0x00, 0x40))
        }
    }
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        returns (bool result)
    {
        assembly {
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, shl(96, owner)))
            mstore(0x00, operator)
            result := sload(keccak256(0x0c, 0x34))
        }
    }
    function setApprovalForAll(address operator, bool isApproved) public virtual {
        assembly {
            operator := shr(96, shl(96, operator))
            isApproved := iszero(iszero(isApproved))
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, shl(96, caller())))
            mstore(0x00, operator)
            sstore(keccak256(0x0c, 0x34), isApproved)
            mstore(0x00, isApproved)
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, caller(), operator)
        }
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        assembly {
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            mstore(0x20, fromSlotSeed)
            from := shr(96, fromSlotSeed)
            to := shr(96, toSlotSeed)
            if iszero(eq(caller(), from)) {
                mstore(0x00, caller())
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            {
                mstore(0x00, id)
                let fromBalanceSlot := keccak256(0x00, 0x40)
                let fromBalance := sload(fromBalanceSlot)
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) 
                    revert(0x1c, 0x04)
                }
                sstore(fromBalanceSlot, sub(fromBalance, amount))
            }
            {
                mstore(0x20, toSlotSeed)
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) 
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            {
                mstore(0x20, amount)
                log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), from, to)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        assembly {
            if extcodesize(to) {
                let m := mload(0x40)
                let onERC1155ReceivedSelector := 0xf23a6e61
                mstore(m, onERC1155ReceivedSelector)
                mstore(add(m, 0x20), caller())
                mstore(add(m, 0x40), from)
                mstore(add(m, 0x60), id)
                mstore(add(m, 0x80), amount)
                mstore(add(m, 0xa0), 0xa0)
                calldatacopy(add(m, 0xc0), sub(data.offset, 0x20), add(0x20, data.length))
                if iszero(call(gas(), to, 0, add(m, 0x1c), add(0xc4, data.length), m, 0x20)) {
                    if returndatasize() {
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    mstore(m, 0)
                }
                if iszero(eq(mload(m), shl(224, onERC1155ReceivedSelector))) {
                    mstore(0x00, 0x9c05499b) 
                    revert(0x1c, 0x04)
                }
            }
        }
    }
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, ids, amounts, data);
        }
        assembly {
            if iszero(eq(ids.length, amounts.length)) {
                mstore(0x00, 0x3b800a46) 
                revert(0x1c, 0x04)
            }
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            mstore(0x20, fromSlotSeed)
            from := shr(96, fromSlotSeed)
            to := shr(96, toSlotSeed)
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            if iszero(eq(caller(), from)) {
                mstore(0x00, caller())
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            {
                let end := shl(5, ids.length)
                for { let i := 0 } iszero(eq(i, end)) { i := add(i, 0x20) } {
                    let amount := calldataload(add(amounts.offset, i))
                    {
                        mstore(0x20, fromSlotSeed)
                        mstore(0x00, calldataload(add(ids.offset, i)))
                        let fromBalanceSlot := keccak256(0x00, 0x40)
                        let fromBalance := sload(fromBalanceSlot)
                        if gt(amount, fromBalance) {
                            mstore(0x00, 0xf4d678b8) 
                            revert(0x1c, 0x04)
                        }
                        sstore(fromBalanceSlot, sub(fromBalance, amount))
                    }
                    {
                        mstore(0x20, toSlotSeed)
                        let toBalanceSlot := keccak256(0x00, 0x40)
                        let toBalanceBefore := sload(toBalanceSlot)
                        let toBalanceAfter := add(toBalanceBefore, amount)
                        if lt(toBalanceAfter, toBalanceBefore) {
                            mstore(0x00, 0x01336cea) 
                            revert(0x1c, 0x04)
                        }
                        sstore(toBalanceSlot, toBalanceAfter)
                    }
                }
            }
            {
                let m := mload(0x40)
                mstore(m, 0x40)
                let n := add(0x20, shl(5, ids.length))
                let o := add(m, 0x40)
                calldatacopy(o, sub(ids.offset, 0x20), n)
                mstore(add(m, 0x20), add(0x40, n))
                o := add(o, n)
                n := add(0x20, shl(5, amounts.length))
                calldatacopy(o, sub(amounts.offset, 0x20), n)
                n := sub(add(o, n), m)
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), from, to)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransferCalldata(from, to, ids, amounts, data);
        }
        assembly {
            if extcodesize(to) {
                let m := mload(0x40)
                let onERC1155BatchReceivedSelector := 0xbc197c81
                mstore(m, onERC1155BatchReceivedSelector)
                mstore(add(m, 0x20), caller())
                mstore(add(m, 0x40), from)
                mstore(add(m, 0x60), 0xa0)
                let n := add(0x20, shl(5, ids.length))
                let o := add(m, 0xc0)
                calldatacopy(o, sub(ids.offset, 0x20), n)
                let s := add(0xa0, n)
                mstore(add(m, 0x80), s)
                o := add(o, n)
                n := add(0x20, shl(5, amounts.length))
                calldatacopy(o, sub(amounts.offset, 0x20), n)
                mstore(add(m, 0xa0), add(s, n))
                o := add(o, n)
                n := add(0x20, data.length)
                calldatacopy(o, sub(data.offset, 0x20), n)
                n := sub(add(o, n), add(m, 0x1c))
                if iszero(call(gas(), to, 0, add(m, 0x1c), n, m, 0x20)) {
                    if returndatasize() {
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    mstore(m, 0)
                }
                if iszero(eq(mload(m), shl(224, onERC1155BatchReceivedSelector))) {
                    mstore(0x00, 0x9c05499b) 
                    revert(0x1c, 0x04)
                }
            }
        }
    }
    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        assembly {
            if iszero(eq(ids.length, owners.length)) {
                mstore(0x00, 0x3b800a46) 
                revert(0x1c, 0x04)
            }
            balances := mload(0x40)
            mstore(balances, ids.length)
            let o := add(balances, 0x20)
            let end := shl(5, ids.length)
            mstore(0x40, add(end, o))
            for { let i := 0 } iszero(eq(i, end)) { i := add(i, 0x20) } {
                let owner := calldataload(add(owners.offset, i))
                mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, shl(96, owner)))
                mstore(0x00, calldataload(add(ids.offset, i)))
                mstore(add(o, i), sload(keccak256(0x00, 0x40)))
            }
        }
    }
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        assembly {
            let s := shr(224, interfaceId)
            result := or(or(eq(s, 0x01ffc9a7), eq(s, 0xd9b67a26)), eq(s, 0x0e89341c))
        }
    }
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(address(0), to, _single(id), _single(amount), data);
        }
        assembly {
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            to := shr(96, toSlotSeed)
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            {
                mstore(0x20, toSlotSeed)
                mstore(0x00, id)
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) 
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            {
                mstore(0x00, id)
                mstore(0x20, amount)
                log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), 0, to)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(address(0), to, _single(id), _single(amount), data);
        }
        if (_hasCode(to)) _checkOnERC1155Received(address(0), to, id, amount, data);
    }
    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(address(0), to, ids, amounts, data);
        }
        assembly {
            if iszero(eq(mload(ids), mload(amounts))) {
                mstore(0x00, 0x3b800a46) 
                revert(0x1c, 0x04)
            }
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            to := shr(96, toSlotSeed)
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            {
                let end := shl(5, mload(ids))
                for { let i := 0 } iszero(eq(i, end)) {} {
                    i := add(i, 0x20)
                    let amount := mload(add(amounts, i))
                    {
                        mstore(0x20, toSlotSeed)
                        mstore(0x00, mload(add(ids, i)))
                        let toBalanceSlot := keccak256(0x00, 0x40)
                        let toBalanceBefore := sload(toBalanceSlot)
                        let toBalanceAfter := add(toBalanceBefore, amount)
                        if lt(toBalanceAfter, toBalanceBefore) {
                            mstore(0x00, 0x01336cea) 
                            revert(0x1c, 0x04)
                        }
                        sstore(toBalanceSlot, toBalanceAfter)
                    }
                }
            }
            {
                let m := mload(0x40)
                mstore(m, 0x40)
                let n := add(0x20, shl(5, mload(ids)))
                let o := add(m, 0x40)
                pop(staticcall(gas(), 4, ids, n, o, n))
                mstore(add(m, 0x20), add(0x40, returndatasize()))
                o := add(o, returndatasize())
                n := add(0x20, shl(5, mload(amounts)))
                pop(staticcall(gas(), 4, amounts, n, o, n))
                n := sub(add(o, returndatasize()), m)
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), 0, to)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(address(0), to, ids, amounts, data);
        }
        if (_hasCode(to)) _checkOnERC1155BatchReceived(address(0), to, ids, amounts, data);
    }
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        _burn(address(0), from, id, amount);
    }
    function _burn(address by, address from, uint256 id, uint256 amount) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, address(0), _single(id), _single(amount), "");
        }
        assembly {
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            mstore(0x20, fromSlotSeed)
            from := shr(96, fromSlotSeed)
            by := shr(96, shl(96, by))
            if iszero(or(iszero(by), eq(by, from))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            {
                mstore(0x00, id)
                let fromBalanceSlot := keccak256(0x00, 0x40)
                let fromBalance := sload(fromBalanceSlot)
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) 
                    revert(0x1c, 0x04)
                }
                sstore(fromBalanceSlot, sub(fromBalance, amount))
            }
            {
                mstore(0x00, id)
                mstore(0x20, amount)
                log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), from, 0)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, address(0), _single(id), _single(amount), "");
        }
    }
    function _batchBurn(address from, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
    {
        _batchBurn(address(0), from, ids, amounts);
    }
    function _batchBurn(address by, address from, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
    {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, address(0), ids, amounts, "");
        }
        assembly {
            if iszero(eq(mload(ids), mload(amounts))) {
                mstore(0x00, 0x3b800a46) 
                revert(0x1c, 0x04)
            }
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            mstore(0x20, fromSlotSeed)
            from := shr(96, fromSlotSeed)
            by := shr(96, shl(96, by))
            if iszero(or(iszero(by), eq(by, from))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            {
                let end := shl(5, mload(ids))
                for { let i := 0 } iszero(eq(i, end)) {} {
                    i := add(i, 0x20)
                    let amount := mload(add(amounts, i))
                    {
                        mstore(0x00, mload(add(ids, i)))
                        let fromBalanceSlot := keccak256(0x00, 0x40)
                        let fromBalance := sload(fromBalanceSlot)
                        if gt(amount, fromBalance) {
                            mstore(0x00, 0xf4d678b8) 
                            revert(0x1c, 0x04)
                        }
                        sstore(fromBalanceSlot, sub(fromBalance, amount))
                    }
                }
            }
            {
                let m := mload(0x40)
                mstore(m, 0x40)
                let n := add(0x20, shl(5, mload(ids)))
                let o := add(m, 0x40)
                pop(staticcall(gas(), 4, ids, n, o, n))
                mstore(add(m, 0x20), add(0x40, returndatasize()))
                o := add(o, returndatasize())
                n := add(0x20, shl(5, mload(amounts)))
                pop(staticcall(gas(), 4, amounts, n, o, n))
                n := sub(add(o, returndatasize()), m)
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), from, 0)
            }
        }
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, address(0), ids, amounts, "");
        }
    }
    function _setApprovalForAll(address by, address operator, bool isApproved) internal virtual {
        assembly {
            operator := shr(96, shl(96, operator))
            isApproved := iszero(iszero(isApproved))
            mstore(0x20, or(_ERC1155_MASTER_SLOT_SEED, shl(96, by)))
            mstore(0x00, operator)
            sstore(keccak256(0x0c, 0x34), isApproved)
            mstore(0x00, isApproved)
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, caller(), operator)
        }
    }
    function _safeTransfer(address from, address to, uint256 id, uint256 amount, bytes memory data)
        internal
        virtual
    {
        _safeTransfer(address(0), from, to, id, amount, data);
    }
    function _safeTransfer(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, _single(id), _single(amount), data);
        }
        assembly {
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            mstore(0x20, fromSlotSeed)
            from := shr(96, fromSlotSeed)
            to := shr(96, toSlotSeed)
            by := shr(96, shl(96, by))
            if iszero(or(iszero(by), eq(by, from))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            {
                mstore(0x00, id)
                let fromBalanceSlot := keccak256(0x00, 0x40)
                let fromBalance := sload(fromBalanceSlot)
                if gt(amount, fromBalance) {
                    mstore(0x00, 0xf4d678b8) 
                    revert(0x1c, 0x04)
                }
                sstore(fromBalanceSlot, sub(fromBalance, amount))
            }
            {
                mstore(0x20, toSlotSeed)
                let toBalanceSlot := keccak256(0x00, 0x40)
                let toBalanceBefore := sload(toBalanceSlot)
                let toBalanceAfter := add(toBalanceBefore, amount)
                if lt(toBalanceAfter, toBalanceBefore) {
                    mstore(0x00, 0x01336cea) 
                    revert(0x1c, 0x04)
                }
                sstore(toBalanceSlot, toBalanceAfter)
            }
            {
                mstore(0x20, amount)
                log4(0x00, 0x40, _TRANSFER_SINGLE_EVENT_SIGNATURE, caller(), from, to)
            }
        }
        if (_hasCode(to)) _checkOnERC1155Received(from, to, id, amount, data);
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, _single(id), _single(amount), data);
        }
    }
    function _safeBatchTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        _safeBatchTransfer(address(0), from, to, ids, amounts, data);
    }
    function _safeBatchTransfer(
        address by,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        if (_useBeforeTokenTransfer()) {
            _beforeTokenTransfer(from, to, ids, amounts, data);
        }
        assembly {
            if iszero(eq(mload(ids), mload(amounts))) {
                mstore(0x00, 0x3b800a46) 
                revert(0x1c, 0x04)
            }
            let fromSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, from))
            let toSlotSeed := or(_ERC1155_MASTER_SLOT_SEED, shl(96, to))
            mstore(0x20, fromSlotSeed)
            from := shr(96, fromSlotSeed)
            to := shr(96, toSlotSeed)
            by := shr(96, shl(96, by))
            if iszero(to) {
                mstore(0x00, 0xea553b34) 
                revert(0x1c, 0x04)
            }
            if iszero(or(iszero(by), eq(by, from))) {
                mstore(0x00, by)
                if iszero(sload(keccak256(0x0c, 0x34))) {
                    mstore(0x00, 0x4b6e7f18) 
                    revert(0x1c, 0x04)
                }
            }
            {
                let end := shl(5, mload(ids))
                for { let i := 0 } iszero(eq(i, end)) {} {
                    i := add(i, 0x20)
                    let amount := mload(add(amounts, i))
                    {
                        mstore(0x20, fromSlotSeed)
                        mstore(0x00, mload(add(ids, i)))
                        let fromBalanceSlot := keccak256(0x00, 0x40)
                        let fromBalance := sload(fromBalanceSlot)
                        if gt(amount, fromBalance) {
                            mstore(0x00, 0xf4d678b8) 
                            revert(0x1c, 0x04)
                        }
                        sstore(fromBalanceSlot, sub(fromBalance, amount))
                    }
                    {
                        mstore(0x20, toSlotSeed)
                        let toBalanceSlot := keccak256(0x00, 0x40)
                        let toBalanceBefore := sload(toBalanceSlot)
                        let toBalanceAfter := add(toBalanceBefore, amount)
                        if lt(toBalanceAfter, toBalanceBefore) {
                            mstore(0x00, 0x01336cea) 
                            revert(0x1c, 0x04)
                        }
                        sstore(toBalanceSlot, toBalanceAfter)
                    }
                }
            }
            {
                let m := mload(0x40)
                mstore(m, 0x40)
                let n := add(0x20, shl(5, mload(ids)))
                let o := add(m, 0x40)
                pop(staticcall(gas(), 4, ids, n, o, n))
                mstore(add(m, 0x20), add(0x40, returndatasize()))
                o := add(o, returndatasize())
                n := add(0x20, shl(5, mload(amounts)))
                pop(staticcall(gas(), 4, amounts, n, o, n))
                n := sub(add(o, returndatasize()), m)
                log4(m, n, _TRANSFER_BATCH_EVENT_SIGNATURE, caller(), from, to)
            }
        }
        if (_hasCode(to)) _checkOnERC1155BatchReceived(from, to, ids, amounts, data);
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, ids, amounts, data);
        }
    }
    function _useBeforeTokenTransfer() internal view virtual returns (bool) {
        return false;
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
    function _useAfterTokenTransfer() internal view virtual returns (bool) {
        return false;
    }
    function _afterTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}
    function _afterTokenTransferCalldata(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) private {
        if (_useAfterTokenTransfer()) {
            _afterTokenTransfer(from, to, ids, amounts, data);
        }
    }
    function _hasCode(address a) private view returns (bool result) {
        assembly {
            result := extcodesize(a) 
        }
    }
    function _checkOnERC1155Received(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        assembly {
            let m := mload(0x40)
            let onERC1155ReceivedSelector := 0xf23a6e61
            mstore(m, onERC1155ReceivedSelector)
            mstore(add(m, 0x20), caller())
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            mstore(add(m, 0x60), id)
            mstore(add(m, 0x80), amount)
            mstore(add(m, 0xa0), 0xa0)
            let n := mload(data)
            mstore(add(m, 0xc0), n)
            if n { pop(staticcall(gas(), 4, add(data, 0x20), n, add(m, 0xe0), n)) }
            if iszero(call(gas(), to, 0, add(m, 0x1c), add(0xc4, n), m, 0x20)) {
                if returndatasize() {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(m, 0)
            }
            if iszero(eq(mload(m), shl(224, onERC1155ReceivedSelector))) {
                mstore(0x00, 0x9c05499b) 
                revert(0x1c, 0x04)
            }
        }
    }
    function _checkOnERC1155BatchReceived(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        assembly {
            let m := mload(0x40)
            let onERC1155BatchReceivedSelector := 0xbc197c81
            mstore(m, onERC1155BatchReceivedSelector)
            mstore(add(m, 0x20), caller())
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            mstore(add(m, 0x60), 0xa0)
            let n := add(0x20, shl(5, mload(ids)))
            let o := add(m, 0xc0)
            pop(staticcall(gas(), 4, ids, n, o, n))
            let s := add(0xa0, returndatasize())
            mstore(add(m, 0x80), s)
            o := add(o, returndatasize())
            n := add(0x20, shl(5, mload(amounts)))
            pop(staticcall(gas(), 4, amounts, n, o, n))
            mstore(add(m, 0xa0), add(s, returndatasize()))
            o := add(o, returndatasize())
            n := add(0x20, mload(data))
            pop(staticcall(gas(), 4, data, n, o, n))
            n := sub(add(o, returndatasize()), add(m, 0x1c))
            if iszero(call(gas(), to, 0, add(m, 0x1c), n, m, 0x20)) {
                if returndatasize() {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(m, 0)
            }
            if iszero(eq(mload(m), shl(224, onERC1155BatchReceivedSelector))) {
                mstore(0x00, 0x9c05499b) 
                revert(0x1c, 0x04)
            }
        }
    }
    function _single(uint256 x) private pure returns (uint256[] memory result) {
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x40))
            mstore(result, 1)
            mstore(add(result, 0x20), x)
        }
    }
}