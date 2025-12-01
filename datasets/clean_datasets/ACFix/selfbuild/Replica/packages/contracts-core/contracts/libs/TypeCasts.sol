pragma solidity 0.7.6;
import "@summa-tx/memview-sol/contracts/TypedMemView.sol";
library TypeCasts {
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    function coerceBytes32(string memory _s)
        internal
        pure
        returns (bytes32 _b)
    {
        _b = bytes(_s).ref(0).index(0, uint8(bytes(_s).length));
    }
    function coerceString(bytes32 _buf)
        internal
        pure
        returns (string memory _newStr)
    {
        uint8 _slen = 0;
        while (_slen < 32 && _buf[_slen] != 0) {
            _slen++;
        }
        assembly {
            _newStr := mload(0x40)
            mstore(0x40, add(_newStr, 0x40)) 
            mstore(_newStr, _slen)
            mstore(add(_newStr, 0x20), _buf)
        }
    }
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }
}