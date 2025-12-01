pragma solidity 0.7.6;
import {Version0} from "./Version0.sol";
import {NomadBase} from "./NomadBase.sol";
import {MerkleLib} from "./libs/Merkle.sol";
import {Message} from "./libs/Message.sol";
import {IMessageRecipient} from "./interfaces/IMessageRecipient.sol";
import {TypedMemView} from "@summa-tx/memview-sol/contracts/TypedMemView.sol";
contract Replica is Version0, NomadBase {
    using MerkleLib for MerkleLib.Tree;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;
    using Message for bytes29;
    bytes32 public constant LEGACY_STATUS_NONE = bytes32(0);
    bytes32 public constant LEGACY_STATUS_PROVEN = bytes32(uint256(1));
    bytes32 public constant LEGACY_STATUS_PROCESSED = bytes32(uint256(2));
    uint32 public remoteDomain;
    uint256 public optimisticSeconds;
    uint8 private entered;
    mapping(bytes32 => uint256) public confirmAt;
    mapping(bytes32 => bytes32) public messages;
    uint256[45] private __GAP;
    event Process(
        bytes32 indexed messageHash,
        bool indexed success,
        bytes indexed returnData
    );
    event SetOptimisticTimeout(uint256 timeout);
    event SetConfirmation(
        bytes32 indexed root,
        uint256 previousConfirmAt,
        uint256 newConfirmAt
    );
    constructor(uint32 _localDomain) NomadBase(_localDomain) {}
    function initialize(
        uint32 _remoteDomain,
        address _updater,
        bytes32 _committedRoot,
        uint256 _optimisticSeconds
    ) public initializer {
        __NomadBase_initialize(_updater);
        entered = 1;
        remoteDomain = _remoteDomain;
        committedRoot = _committedRoot;
        confirmAt[_committedRoot] = 1;
        _setOptimisticTimeout(_optimisticSeconds);
    }
    function update(
        bytes32 _oldRoot,
        bytes32 _newRoot,
        bytes memory _signature
    ) external {
        require(_oldRoot == committedRoot, "not current update");
        require(
            _isUpdaterSignature(_oldRoot, _newRoot, _signature),
            "!updater sig"
        );
        _beforeUpdate();
        confirmAt[_newRoot] = block.timestamp + optimisticSeconds;
        committedRoot = _newRoot;
        emit Update(remoteDomain, _oldRoot, _newRoot, _signature);
    }
    function proveAndProcess(
        bytes memory _message,
        bytes32[32] calldata _proof,
        uint256 _index
    ) external {
        require(prove(keccak256(_message), _proof, _index), "!prove");
        process(_message);
    }
    function process(bytes memory _message) public returns (bool _success) {
        bytes29 _m = _message.ref(0);
        require(_m.destination() == localDomain, "!destination");
        bytes32 _messageHash = _m.keccak();
        require(acceptableRoot(messages[_messageHash]), "!proven");
        require(entered == 1, "!reentrant");
        entered = 0;
        messages[_messageHash] = LEGACY_STATUS_PROCESSED;
        IMessageRecipient(_m.recipientAddress()).handle(
            _m.origin(),
            _m.nonce(),
            _m.sender(),
            _m.body().clone()
        );
        emit Process(_messageHash, true, "");
        entered = 1;
        return true;
    }
    function setOptimisticTimeout(uint256 _optimisticSeconds)
        external
        onlyOwner
    {
        _setOptimisticTimeout(_optimisticSeconds);
    }
    function setUpdater(address _updater) external onlyOwner {
        _setUpdater(_updater);
    }
    function setConfirmation(bytes32 _root, uint256 _confirmAt)
        external
        onlyOwner
    {
        uint256 _previousConfirmAt = confirmAt[_root];
        confirmAt[_root] = _confirmAt;
        emit SetConfirmation(_root, _previousConfirmAt, _confirmAt);
    }
    function acceptableRoot(bytes32 _root) public view returns (bool) {
        if (_root == LEGACY_STATUS_PROVEN) return true;
        if (_root == LEGACY_STATUS_PROCESSED) return false;
        uint256 _time = confirmAt[_root];
        if (_time == 0) {
            return false;
        }
        return block.timestamp >= _time;
    }
    function prove(
        bytes32 _leaf,
        bytes32[32] calldata _proof,
        uint256 _index
    ) public returns (bool) {
        require(
            messages[_leaf] != LEGACY_STATUS_PROCESSED,
            "already processed"
        );
        bytes32 _calculatedRoot = MerkleLib.branchRoot(_leaf, _proof, _index);
        if (acceptableRoot(_calculatedRoot)) {
            messages[_leaf] = _calculatedRoot;
            return true;
        }
        return false;
    }
    function homeDomainHash() public view override returns (bytes32) {
        return _homeDomainHash(remoteDomain);
    }
    function _setOptimisticTimeout(uint256 _optimisticSeconds) internal {
        uint256 _current = optimisticSeconds;
        if (_current != 0 && _current > 1500)
            require(_optimisticSeconds >= 1500, "optimistic timeout too low");
        require(_optimisticSeconds < 31536000, "optimistic timeout too high");
        optimisticSeconds = _optimisticSeconds;
        emit SetOptimisticTimeout(_optimisticSeconds);
    }
    function _beforeUpdate() internal {}
}