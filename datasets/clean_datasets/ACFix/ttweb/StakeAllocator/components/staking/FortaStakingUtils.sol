pragma solidity ^0.8.9;
library FortaStakingUtils {
    function subjectToActive(uint8 subjectType, uint256 subject) internal pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(subjectType, subject))) << 9 | uint16(256)) | uint256(subjectType);
    }
    function subjectToInactive(uint8 subjectType, uint256 subject) internal pure returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(subjectType, subject))) << 9) | uint256(subjectType);
    }
    function activeToInactive(uint256 activeSharesId) internal pure returns (uint256) {
        return activeSharesId & (~uint256(1 << 8));
    }
    function inactiveToActive(uint256 inactiveSharesId) internal pure returns (uint256) {
        return inactiveSharesId | (1 << 8);
    }
    function isActive(uint256 sharesId) internal pure returns(bool) {
        return sharesId & (1 << 8) == 256;
    }
    function subjectTypeOfShares(uint256 sharesId) internal pure returns(uint8) {
        return uint8(sharesId);
    }
}