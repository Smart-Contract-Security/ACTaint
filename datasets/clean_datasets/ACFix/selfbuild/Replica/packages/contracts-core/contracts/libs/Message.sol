pragma solidity 0.7.6;
import "@summa-tx/memview-sol/contracts/TypedMemView.sol";
import {TypeCasts} from "./TypeCasts.sol";
library Message {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    uint256 internal constant PREFIX_LENGTH = 76;
    function formatMessage(
        uint32 _originDomain,
        bytes32 _sender,
        uint32 _nonce,
        uint32 _destinationDomain,
        bytes32 _recipient,
        bytes memory _messageBody
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _originDomain,
                _sender,
                _nonce,
                _destinationDomain,
                _recipient,
                _messageBody
            );
    }
    function messageHash(
        uint32 _origin,
        bytes32 _sender,
        uint32 _nonce,
        uint32 _destination,
        bytes32 _recipient,
        bytes memory _body
    ) internal pure returns (bytes32) {
        return
            keccak256(
                formatMessage(
                    _origin,
                    _sender,
                    _nonce,
                    _destination,
                    _recipient,
                    _body
                )
            );
    }
    function origin(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(0, 4));
    }
    function sender(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(4, 32);
    }
    function nonce(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(36, 4));
    }
    function destination(bytes29 _message) internal pure returns (uint32) {
        return uint32(_message.indexUint(40, 4));
    }
    function recipient(bytes29 _message) internal pure returns (bytes32) {
        return _message.index(44, 32);
    }
    function recipientAddress(bytes29 _message)
        internal
        pure
        returns (address)
    {
        return TypeCasts.bytes32ToAddress(recipient(_message));
    }
    function body(bytes29 _message) internal pure returns (bytes29) {
        return _message.slice(PREFIX_LENGTH, _message.len() - PREFIX_LENGTH, 0);
    }
    function leaf(bytes29 _message) internal view returns (bytes32) {
        return
            messageHash(
                origin(_message),
                sender(_message),
                nonce(_message),
                destination(_message),
                recipient(_message),
                TypedMemView.clone(body(_message))
            );
    }
}