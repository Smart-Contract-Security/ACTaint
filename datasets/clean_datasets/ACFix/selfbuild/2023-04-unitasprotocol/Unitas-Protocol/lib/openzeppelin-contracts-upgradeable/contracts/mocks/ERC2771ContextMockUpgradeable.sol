pragma solidity ^0.8.9;
import "./ContextMockUpgradeable.sol";
import "../metatx/ERC2771ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
contract ERC2771ContextMockUpgradeable is Initializable, ContextMockUpgradeable, ERC2771ContextUpgradeable {
    constructor(address trustedForwarder) ERC2771ContextUpgradeable(trustedForwarder) {
        emit Sender(_msgSender()); 
    }
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }
    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
    uint256[50] private __gap;
}