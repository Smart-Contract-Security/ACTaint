pragma solidity ^0.7.0;
import "./BalancerErrors.sol";
import "./ISignaturesValidator.sol";
import "../openzeppelin/EIP712.sol";
abstract contract SignaturesValidator is ISignaturesValidator, EIP712 {
    uint256 internal constant _EXTRA_CALLDATA_LENGTH = 4 * 32;
    mapping(address => uint256) internal _nextNonce;
    constructor(string memory name) EIP712(name, "1") {
    }
    function getDomainSeparator() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }
    function getNextNonce(address user) external view override returns (uint256) {
        return _nextNonce[user];
    }
    function _validateSignature(address user, uint256 errorCode) internal {
        uint256 nextNonce = _nextNonce[user]++;
        _require(_isSignatureValid(user, nextNonce), errorCode);
    }
    function _isSignatureValid(address user, uint256 nonce) private view returns (bool) {
        uint256 deadline = _deadline();
        if (deadline < block.timestamp) {
            return false;
        }
        bytes32 typeHash = _typeHash();
        if (typeHash == bytes32(0)) {
            return false;
        }
        bytes32 structHash = keccak256(abi.encode(typeHash, keccak256(_calldata()), msg.sender, nonce, deadline));
        bytes32 digest = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = _signature();
        address recoveredAddress = ecrecover(digest, v, r, s);
        return recoveredAddress != address(0) && recoveredAddress == user;
    }
    function _typeHash() internal view virtual returns (bytes32);
    function _deadline() internal pure returns (uint256) {
        return uint256(_decodeExtraCalldataWord(0));
    }
    function _signature()
        internal
        pure
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        v = uint8(uint256(_decodeExtraCalldataWord(0x20)));
        r = _decodeExtraCalldataWord(0x40);
        s = _decodeExtraCalldataWord(0x60);
    }
    function _calldata() internal pure returns (bytes memory result) {
        result = msg.data; 
        if (result.length > _EXTRA_CALLDATA_LENGTH) {
            assembly {
                mstore(result, sub(calldatasize(), _EXTRA_CALLDATA_LENGTH))
            }
        }
    }
    function _decodeExtraCalldataWord(uint256 offset) private pure returns (bytes32 result) {
        assembly {
            result := calldataload(add(sub(calldatasize(), _EXTRA_CALLDATA_LENGTH), offset))
        }
    }
}