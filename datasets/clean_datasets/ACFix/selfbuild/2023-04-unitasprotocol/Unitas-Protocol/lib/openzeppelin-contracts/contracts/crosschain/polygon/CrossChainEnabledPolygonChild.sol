pragma solidity ^0.8.4;
import "../CrossChainEnabled.sol";
import "../../security/ReentrancyGuard.sol";
import "../../utils/Address.sol";
import "../../vendor/polygon/IFxMessageProcessor.sol";
address constant DEFAULT_SENDER = 0x000000000000000000000000000000000000dEaD;
abstract contract CrossChainEnabledPolygonChild is IFxMessageProcessor, CrossChainEnabled, ReentrancyGuard {
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
        Address.functionDelegateCall(address(this), data, "cross-chain execution failed");
        _sender = DEFAULT_SENDER;
    }
}