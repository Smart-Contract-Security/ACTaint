pragma solidity ^0.8.17;
import {LibSort} from "solady/utils/LibSort.sol";
type PackedRecipient is uint256;
library LibRecipients {
    using LibSort for uint256[];
    error InvalidRecipients_ArrayLengthMismatch();
    uint256 constant UINT96_BITS = 96;
    function _sortRecipients(address[] calldata accounts_, uint32[] calldata percentAllocations_)
        internal
        pure
        returns (address[] memory, uint32[] memory)
    {
        PackedRecipient[] memory packedRecipients = _packRecipients(accounts_, percentAllocations_);
        _sortInPlace(packedRecipients);
        return _unpackAccountsInPlace(packedRecipients);
    }
    function _sortRecipientsInPlace(address[] memory accounts_, uint32[] memory percentAllocations_) internal pure {
        PackedRecipient[] memory packedRecipients = _packRecipientsIntoAccounts(accounts_, percentAllocations_);
        _sortInPlace(packedRecipients);
        _unpackAccountsAndAllocationsInPlace(packedRecipients, percentAllocations_);
    }
    function _packRecipients(address[] calldata accounts_, uint32[] calldata percentAllocations_)
        internal
        pure
        returns (PackedRecipient[] memory packedRecipients)
    {
        if (accounts_.length != percentAllocations_.length) revert InvalidRecipients_ArrayLengthMismatch();
        uint256 length = accounts_.length;
        packedRecipients = new PackedRecipient[](length);
        for (uint256 i; i < length;) {
            packedRecipients[i] = _pack(accounts_[i], percentAllocations_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function _packRecipientsIntoAccounts(address[] memory accounts_, uint32[] memory percentAllocations_)
        internal
        pure
        returns (PackedRecipient[] memory packedRecipients)
    {
        if (accounts_.length != percentAllocations_.length) revert InvalidRecipients_ArrayLengthMismatch();
        assembly ("memory-safe") {
            packedRecipients := accounts_
        }
        uint256 length = accounts_.length;
        for (uint256 i; i < length;) {
            packedRecipients[i] = _pack(accounts_[i], percentAllocations_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function _sortInPlace(PackedRecipient[] memory packedRecipients_) internal pure {
        uint256[] memory uintPackedRecipients;
        assembly ("memory-safe") {
            uintPackedRecipients := packedRecipients_
        }
        uintPackedRecipients.sort();
    }
    function _unpackAccountsInPlace(PackedRecipient[] memory packedRecipients_)
        internal
        pure
        returns (address[] memory accounts, uint32[] memory percentAllocations)
    {
        uint256 length = packedRecipients_.length;
        assembly ("memory-safe") {
            accounts := packedRecipients_
        }
        percentAllocations = new uint32[](length);
        for (uint256 i; i < length;) {
            (accounts[i], percentAllocations[i]) = _unpack(packedRecipients_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function _unpackAccountsAndAllocationsInPlace(
        PackedRecipient[] memory packedRecipients_,
        uint32[] memory percentAllocations_
    ) internal pure {
        if (packedRecipients_.length != percentAllocations_.length) revert InvalidRecipients_ArrayLengthMismatch();
        address[] memory accounts;
        assembly ("memory-safe") {
            accounts := packedRecipients_
        }
        uint256 length = packedRecipients_.length;
        for (uint256 i; i < length;) {
            (accounts[i], percentAllocations_[i]) = _unpack(packedRecipients_[i]);
            unchecked {
                ++i;
            }
        }
    }
    function _pack(address account_, uint32 percentAllocation_) internal pure returns (PackedRecipient) {
        return PackedRecipient.wrap((uint256(uint160(account_)) << UINT96_BITS) | percentAllocation_);
    }
    function _unpack(PackedRecipient packedRecipient_)
        internal
        pure
        returns (address account, uint32 percentAllocation)
    {
        uint256 packedRecipient = PackedRecipient.unwrap(packedRecipient_);
        percentAllocation = uint32(packedRecipient);
        account = address(uint160(packedRecipient >> UINT96_BITS));
    }
}