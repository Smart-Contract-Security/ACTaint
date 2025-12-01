pragma solidity >=0.8.0;
import {Bytes32AddressLib} from "./Bytes32AddressLib.sol";
library LibRLP {
    using Bytes32AddressLib for bytes32;
    function computeAddress(address deployer, uint256 nonce) internal pure returns (address) {
        if (nonce == 0x00)             return keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80))).fromLast20Bytes();
        if (nonce <= 0x7f)             return keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce))).fromLast20Bytes();
        if (nonce <= type(uint8).max)  return keccak256(abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce))).fromLast20Bytes();
        if (nonce <= type(uint16).max) return keccak256(abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce))).fromLast20Bytes();
        if (nonce <= type(uint24).max) return keccak256(abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce))).fromLast20Bytes();
        return keccak256(abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce))).fromLast20Bytes();
    }
}