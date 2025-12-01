pragma solidity ^0.8.19;
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
function _errorMessage(uint256 errorCode) pure returns (bytes memory) {
    return bytes(string.concat("Unitas: ", StringsUpgradeable.toString(errorCode)));
}