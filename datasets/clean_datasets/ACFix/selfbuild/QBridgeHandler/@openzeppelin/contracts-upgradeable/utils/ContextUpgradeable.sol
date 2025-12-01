pragma solidity >=0.6.0 <0.8.0;
import "../proxy/Initializable.sol";
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }
    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
    uint256[50] private __gap;
}