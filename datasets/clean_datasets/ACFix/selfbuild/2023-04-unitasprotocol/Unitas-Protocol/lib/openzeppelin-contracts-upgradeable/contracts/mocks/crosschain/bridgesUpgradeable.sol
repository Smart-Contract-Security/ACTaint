pragma solidity ^0.8.0;
import "../../utils/AddressUpgradeable.sol";
import "../../vendor/polygon/IFxMessageProcessorUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract BaseRelayMockUpgradeable is Initializable {
    function __BaseRelayMock_init() internal onlyInitializing {
    }
    function __BaseRelayMock_init_unchained() internal onlyInitializing {
    }
    error NotCrossChainCall();
    error InvalidCrossChainSender(address sender, address expected);
    address internal _currentSender;
    function relayAs(
        address target,
        bytes calldata data,
        address sender
    ) external virtual {
        address previousSender = _currentSender;
        _currentSender = sender;
        (bool success, bytes memory returndata) = target.call(data);
        AddressUpgradeable.verifyCallResultFromTarget(target, success, returndata, "low-level call reverted");
        _currentSender = previousSender;
    }
    uint256[49] private __gap;
}
contract BridgeAMBMockUpgradeable is Initializable, BaseRelayMockUpgradeable {
    function __BridgeAMBMock_init() internal onlyInitializing {
    }
    function __BridgeAMBMock_init_unchained() internal onlyInitializing {
    }
    function messageSender() public view returns (address) {
        return _currentSender;
    }
    uint256[50] private __gap;
}
contract BridgeArbitrumL1MockUpgradeable is Initializable, BaseRelayMockUpgradeable {
    function __BridgeArbitrumL1Mock_init() internal onlyInitializing {
    }
    function __BridgeArbitrumL1Mock_init_unchained() internal onlyInitializing {
    }
    address public immutable inbox = address(new BridgeArbitrumL1InboxUpgradeable());
    address public immutable outbox = address(new BridgeArbitrumL1OutboxUpgradeable());
    function activeOutbox() public view returns (address) {
        return outbox;
    }
    function currentSender() public view returns (address) {
        return _currentSender;
    }
    uint256[50] private __gap;
}
contract BridgeArbitrumL1InboxUpgradeable is Initializable {
    function __BridgeArbitrumL1Inbox_init() internal onlyInitializing {
    }
    function __BridgeArbitrumL1Inbox_init_unchained() internal onlyInitializing {
    }
    address public immutable bridge = msg.sender;
    uint256[50] private __gap;
}
contract BridgeArbitrumL1OutboxUpgradeable is Initializable {
    function __BridgeArbitrumL1Outbox_init() internal onlyInitializing {
    }
    function __BridgeArbitrumL1Outbox_init_unchained() internal onlyInitializing {
    }
    address public immutable bridge = msg.sender;
    function l2ToL1Sender() public view returns (address) {
        return BridgeArbitrumL1MockUpgradeable(bridge).currentSender();
    }
    uint256[50] private __gap;
}
contract BridgeArbitrumL2MockUpgradeable is Initializable, BaseRelayMockUpgradeable {
    function __BridgeArbitrumL2Mock_init() internal onlyInitializing {
    }
    function __BridgeArbitrumL2Mock_init_unchained() internal onlyInitializing {
    }
    function wasMyCallersAddressAliased() public view returns (bool) {
        return _currentSender != address(0);
    }
    function myCallersAddressWithoutAliasing() public view returns (address) {
        return _currentSender;
    }
    uint256[50] private __gap;
}
contract BridgeOptimismMockUpgradeable is Initializable, BaseRelayMockUpgradeable {
    function __BridgeOptimismMock_init() internal onlyInitializing {
    }
    function __BridgeOptimismMock_init_unchained() internal onlyInitializing {
    }
    function xDomainMessageSender() public view returns (address) {
        return _currentSender;
    }
    uint256[50] private __gap;
}
contract BridgePolygonChildMockUpgradeable is Initializable, BaseRelayMockUpgradeable {
    function __BridgePolygonChildMock_init() internal onlyInitializing {
    }
    function __BridgePolygonChildMock_init_unchained() internal onlyInitializing {
    }
    function relayAs(
        address target,
        bytes calldata data,
        address sender
    ) external override {
        IFxMessageProcessorUpgradeable(target).processMessageFromRoot(0, sender, data);
    }
    uint256[50] private __gap;
}