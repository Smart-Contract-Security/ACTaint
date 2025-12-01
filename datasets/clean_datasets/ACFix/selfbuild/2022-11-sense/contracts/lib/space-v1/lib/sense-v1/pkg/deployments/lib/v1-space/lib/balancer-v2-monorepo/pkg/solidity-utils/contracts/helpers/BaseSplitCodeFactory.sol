pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./BalancerErrors.sol";
import "./CodeDeployer.sol";
abstract contract BaseSplitCodeFactory {
    address private immutable _creationCodeContractA;
    uint256 private immutable _creationCodeSizeA;
    address private immutable _creationCodeContractB;
    uint256 private immutable _creationCodeSizeB;
    constructor(bytes memory creationCode) {
        uint256 creationCodeSize = creationCode.length;
        uint256 creationCodeSizeA = creationCodeSize / 2;
        _creationCodeSizeA = creationCodeSizeA;
        uint256 creationCodeSizeB = creationCodeSize - creationCodeSizeA;
        _creationCodeSizeB = creationCodeSizeB;
        bytes memory creationCodeA;
        assembly {
            creationCodeA := creationCode
            mstore(creationCodeA, creationCodeSizeA)
        }
        _creationCodeContractA = CodeDeployer.deploy(creationCodeA);
        bytes memory creationCodeB;
        bytes32 lastByteA;
        assembly {
            creationCodeB := add(creationCode, creationCodeSizeA)
            lastByteA := mload(creationCodeB)
            mstore(creationCodeB, creationCodeSizeB)
        }
        _creationCodeContractB = CodeDeployer.deploy(creationCodeB);
        assembly {
            mstore(creationCodeA, creationCodeSize)
            mstore(creationCodeB, lastByteA)
        }
    }
    function getCreationCodeContracts() public view returns (address contractA, address contractB) {
        return (_creationCodeContractA, _creationCodeContractB);
    }
    function getCreationCode() public view returns (bytes memory) {
        return _getCreationCodeWithArgs("");
    }
    function _getCreationCodeWithArgs(bytes memory constructorArgs) private view returns (bytes memory code) {
        address creationCodeContractA = _creationCodeContractA;
        uint256 creationCodeSizeA = _creationCodeSizeA;
        address creationCodeContractB = _creationCodeContractB;
        uint256 creationCodeSizeB = _creationCodeSizeB;
        uint256 creationCodeSize = creationCodeSizeA + creationCodeSizeB;
        uint256 constructorArgsSize = constructorArgs.length;
        uint256 codeSize = creationCodeSize + constructorArgsSize;
        assembly {
            code := mload(0x40)
            mstore(0x40, add(code, add(codeSize, 32)))
            mstore(code, codeSize)
            let dataStart := add(code, 32)
            extcodecopy(creationCodeContractA, dataStart, 0, creationCodeSizeA)
            extcodecopy(creationCodeContractB, add(dataStart, creationCodeSizeA), 0, creationCodeSizeB)
        }
        uint256 constructorArgsDataPtr;
        uint256 constructorArgsCodeDataPtr;
        assembly {
            constructorArgsDataPtr := add(constructorArgs, 32)
            constructorArgsCodeDataPtr := add(add(code, 32), creationCodeSize)
        }
        _memcpy(constructorArgsCodeDataPtr, constructorArgsDataPtr, constructorArgsSize);
    }
    function _create(bytes memory constructorArgs) internal virtual returns (address) {
        bytes memory creationCode = _getCreationCodeWithArgs(constructorArgs);
        address destination;
        assembly {
            destination := create(0, add(creationCode, 32), mload(creationCode))
        }
        if (destination == address(0)) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        return destination;
    }
    function _memcpy(
        uint256 dest,
        uint256 src,
        uint256 len
    ) private pure {
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
        uint256 mask = 256**(32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
}