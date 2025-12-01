pragma solidity ^0.8.4;
library LibClone {
    error DeploymentFailed();
    error SaltDoesNotStartWithCaller();
    function clone(address implementation) internal returns (address instance) {
        assembly {
            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            instance := create(0, 0x0c, 0x35)
            mstore(0x21, 0)
            if iszero(instance) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
        }
    }
    function cloneDeterministic(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        assembly {
            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            instance := create2(0, 0x0c, 0x35, salt)
            mstore(0x21, 0)
            if iszero(instance) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
        }
    }
    function initCodeHash(address implementation) internal pure returns (bytes32 hash) {
        assembly {
            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
            hash := keccak256(0x0c, 0x35)
            mstore(0x21, 0)
        }
    }
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(implementation);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }
    function clone(address implementation, bytes memory data) internal returns (address instance) {
        assembly {
            let mBefore3 := mload(sub(data, 0x60))
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)
            let extraLength := add(dataLength, 2)
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            mstore(sub(data, 0x0d), implementation)
            mstore(
                sub(data, 0x21),
                or(shl(0x48, extraLength), 0x593da1005b363d3d373d3d3d3d610000806062363936013d73)
            )
            mstore(
                sub(data, 0x3a), 0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                sub(data, 0x5a),
                or(shl(0x78, add(extraLength, 0x62)), 0x6100003d81600a3d39f336602c57343d527f)
            )
            mstore(dataEnd, shl(0xf0, extraLength))
            instance := create(0, sub(data, 0x4c), add(extraLength, 0x6c))
            if iszero(instance) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
            mstore(sub(data, 0x60), mBefore3)
        }
    }
    function cloneDeterministic(address implementation, bytes memory data, bytes32 salt)
        internal
        returns (address instance)
    {
        assembly {
            let mBefore3 := mload(sub(data, 0x60))
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)
            let extraLength := add(dataLength, 2)
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            mstore(sub(data, 0x0d), implementation)
            mstore(
                sub(data, 0x21),
                or(shl(0x48, extraLength), 0x593da1005b363d3d373d3d3d3d610000806062363936013d73)
            )
            mstore(
                sub(data, 0x3a), 0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                sub(data, 0x5a),
                or(shl(0x78, add(extraLength, 0x62)), 0x6100003d81600a3d39f336602c57343d527f)
            )
            mstore(dataEnd, shl(0xf0, extraLength))
            instance := create2(0, sub(data, 0x4c), add(extraLength, 0x6c), salt)
            if iszero(instance) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
            mstore(sub(data, 0x60), mBefore3)
        }
    }
    function initCodeHash(address implementation, bytes memory data)
        internal
        pure
        returns (bytes32 hash)
    {
        assembly {
            let mBefore3 := mload(sub(data, 0x60))
            let mBefore2 := mload(sub(data, 0x40))
            let mBefore1 := mload(sub(data, 0x20))
            let dataLength := mload(data)
            let dataEnd := add(add(data, 0x20), dataLength)
            let mAfter1 := mload(dataEnd)
            let extraLength := add(dataLength, 2)
            mstore(data, 0x5af43d3d93803e606057fd5bf3)
            mstore(sub(data, 0x0d), implementation)
            mstore(
                sub(data, 0x21),
                or(shl(0x48, extraLength), 0x593da1005b363d3d373d3d3d3d610000806062363936013d73)
            )
            mstore(
                sub(data, 0x3a), 0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff
            )
            mstore(
                sub(data, 0x5a),
                or(shl(0x78, add(extraLength, 0x62)), 0x6100003d81600a3d39f336602c57343d527f)
            )
            mstore(dataEnd, shl(0xf0, extraLength))
            hash := keccak256(sub(data, 0x4c), add(extraLength, 0x6c))
            mstore(dataEnd, mAfter1)
            mstore(data, dataLength)
            mstore(sub(data, 0x20), mBefore1)
            mstore(sub(data, 0x40), mBefore2)
            mstore(sub(data, 0x60), mBefore3)
        }
    }
    function predictDeterministicAddress(
        address implementation,
        bytes memory data,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes32 hash = initCodeHash(implementation, data);
        predicted = predictDeterministicAddress(hash, salt, deployer);
    }
    function predictDeterministicAddress(bytes32 hash, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        assembly {
            mstore8(0x00, 0xff) 
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            mstore(0x35, 0)
        }
    }
    function checkStartsWithCaller(bytes32 salt) internal view {
        assembly {
            if iszero(or(iszero(shr(96, salt)), eq(caller(), shr(96, salt)))) {
                mstore(0x00, 0x2f634836)
                revert(0x1c, 0x04)
            }
        }
    }
}