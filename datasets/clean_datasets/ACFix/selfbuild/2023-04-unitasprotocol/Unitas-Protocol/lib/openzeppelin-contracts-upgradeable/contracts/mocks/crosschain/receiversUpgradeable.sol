pragma solidity ^0.8.4;
import "../../access/OwnableUpgradeable.sol";
import "../../crosschain/amb/CrossChainEnabledAMBUpgradeable.sol";
import "../../crosschain/arbitrum/CrossChainEnabledArbitrumL1Upgradeable.sol";
import "../../crosschain/arbitrum/CrossChainEnabledArbitrumL2Upgradeable.sol";
import "../../crosschain/optimism/CrossChainEnabledOptimismUpgradeable.sol";
import "../../crosschain/polygon/CrossChainEnabledPolygonChildUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract ReceiverUpgradeable is Initializable, CrossChainEnabledUpgradeable {
    function __Receiver_init() internal onlyInitializing {
    }
    function __Receiver_init_unchained() internal onlyInitializing {
    }
    address public immutable owner = msg.sender;
    function crossChainRestricted() external onlyCrossChain {}
    function crossChainOwnerRestricted() external onlyCrossChainSender(owner) {}
    uint256[50] private __gap;
}
contract CrossChainEnabledAMBMockUpgradeable is Initializable, ReceiverUpgradeable, CrossChainEnabledAMBUpgradeable {
    constructor(address bridge) CrossChainEnabledAMBUpgradeable(bridge) {}
    uint256[50] private __gap;
}
contract CrossChainEnabledArbitrumL1MockUpgradeable is Initializable, ReceiverUpgradeable, CrossChainEnabledArbitrumL1Upgradeable {
    constructor(address bridge) CrossChainEnabledArbitrumL1Upgradeable(bridge) {}
    uint256[50] private __gap;
}
contract CrossChainEnabledArbitrumL2MockUpgradeable is Initializable, ReceiverUpgradeable, CrossChainEnabledArbitrumL2Upgradeable {    function __CrossChainEnabledArbitrumL2Mock_init() internal onlyInitializing {
    }
    function __CrossChainEnabledArbitrumL2Mock_init_unchained() internal onlyInitializing {
    }
    uint256[50] private __gap;
}
contract CrossChainEnabledOptimismMockUpgradeable is Initializable, ReceiverUpgradeable, CrossChainEnabledOptimismUpgradeable {
    constructor(address bridge) CrossChainEnabledOptimismUpgradeable(bridge) {}
    uint256[50] private __gap;
}
contract CrossChainEnabledPolygonChildMockUpgradeable is Initializable, ReceiverUpgradeable, CrossChainEnabledPolygonChildUpgradeable {
    constructor(address bridge) CrossChainEnabledPolygonChildUpgradeable(bridge) {}
    uint256[50] private __gap;
}