pragma solidity >=0.8.0;
import './AddressStringUtil.sol';
library SafeERC20Namer {
    function bytes32ToString(bytes32 x) private pure returns (string memory) {
        bytes memory bytesString = new bytes(32);
        uint256 charCount = 0;
        for (uint256 j = 0; j < 32; j++) {
            bytes1 char = x[j];
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint256 j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
    function parseStringData(bytes memory b) private pure returns (string memory) {
        uint256 charCount = 0;
        for (uint256 i = 32; i < 64; i++) {
            charCount <<= 8;
            charCount += uint8(b[i]);
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (uint256 i = 0; i < charCount; i++) {
            bytesStringTrimmed[i] = b[i + 64];
        }
        return string(bytesStringTrimmed);
    }
    function addressToName(address token) private pure returns (string memory) {
        return AddressStringUtil.toAsciiString(token, 40);
    }
    function addressToSymbol(address token) private pure returns (string memory) {
        return AddressStringUtil.toAsciiString(token, 6);
    }
    function callAndParseStringReturn(address token, bytes4 selector) private view returns (string memory) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSelector(selector));
        if (!success || data.length == 0) {
            return '';
        }
        if (data.length == 32) {
            bytes32 decoded = abi.decode(data, (bytes32));
            return bytes32ToString(decoded);
        } else if (data.length > 64) {
            return abi.decode(data, (string));
        }
        return '';
    }
    function tokenSymbol(address token) internal view returns (string memory) {
        string memory symbol = callAndParseStringReturn(token, 0x95d89b41);
        if (bytes(symbol).length == 0) {
            return addressToSymbol(token);
        }
        return symbol;
    }
    function tokenName(address token) internal view returns (string memory) {
        string memory name = callAndParseStringReturn(token, 0x06fdde03);
        if (bytes(name).length == 0) {
            return addressToName(token);
        }
        return name;
    }
}