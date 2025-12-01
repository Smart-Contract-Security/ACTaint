pragma solidity 0.8.9;
import "../lib/EIP712.sol";
import "../lib/Types.sol";
contract TestOrder {
    function getOrderHash(bytes32 domainSeparator, Types.Order memory order)
        external
        pure
        returns (bytes32 orderHash)
    {
        orderHash = EIP712._hashTypedDataV4(
            domainSeparator,
            _structHash(order)
        );
    }
    function _structHash(Types.Order memory order)
        private
        pure
        returns (bytes32 structHash)
    {
        bytes32 orderTypeHash = Types.ORDER_TYPEHASH;
        assembly {
            let start := sub(order, 32)
            let tmp := mload(start)
            mstore(start, orderTypeHash)
            structHash := keccak256(start, 224)
            mstore(start, tmp)
        }
    }
}