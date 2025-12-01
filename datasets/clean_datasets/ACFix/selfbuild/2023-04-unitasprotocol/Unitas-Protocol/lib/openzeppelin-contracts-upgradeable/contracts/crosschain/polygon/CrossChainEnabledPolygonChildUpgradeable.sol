pragma solidity ^0.8.4;
import "../CrossChainEnabledUpgradeable.sol";
import "../../security/ReentrancyGuardUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../vendor/polygon/IFxMessageProcessorUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
address constant DEFAULT_SENDER = 0x000000000000000000000000000000000000dEaD;
abstract contract CrossChainEnabledPolygonChildUpgradeable is Initializable, IFxMessageProcessorUpgradeable, CrossChainEnabledUpgradeable, ReentrancyGuardUpgradeable {
    address private immutable _fxChild;
    address private _sender = DEFAULT_SENDER;
    constructor(address fxChild) {
        _fxChild = fxChild;
    }
    function _isCrossChain() internal view virtual override returns (bool) {
        return msg.sender == _fxChild;
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return _sender;
    }
    function processMessageFromRoot(
        uint256, 
        address rootMessageSender,
        bytes calldata data
    ) external override nonReentrant {
        if (!_isCrossChain()) revert NotCrossChainCall();
        _sender = rootMessageSender;
        __functionDelegateCall(address(this), data);
        _sender = DEFAULT_SENDER;
    }
    function __functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }
    uint256[49] private __gap;
}