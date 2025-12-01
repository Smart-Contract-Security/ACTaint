pragma solidity 0.7.6;
import {Message} from "./libs/Message.sol";
import {ECDSA} from "@openzeppelin/contracts/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
abstract contract NomadBase is Initializable, OwnableUpgradeable {
    enum States {
        UnInitialized,
        Active,
        Failed
    }
    uint32 public immutable localDomain;
    address public updater;
    States public state;
    bytes32 public committedRoot;
    uint256[47] private __GAP;
    event Update(
        uint32 indexed homeDomain,
        bytes32 indexed oldRoot,
        bytes32 indexed newRoot,
        bytes signature
    );
    event NewUpdater(address oldUpdater, address newUpdater);
    constructor(uint32 _localDomain) {
        localDomain = _localDomain;
    }
    function __NomadBase_initialize(address _updater) internal initializer {
        __Ownable_init();
        _setUpdater(_updater);
        state = States.Active;
    }
    function homeDomainHash() public view virtual returns (bytes32);
    function _homeDomainHash(uint32 _homeDomain)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_homeDomain, "NOMAD"));
    }
    function _setUpdater(address _newUpdater) internal {
        address _oldUpdater = updater;
        updater = _newUpdater;
        emit NewUpdater(_oldUpdater, _newUpdater);
    }
    function _isUpdaterSignature(
        bytes32 _oldRoot,
        bytes32 _newRoot,
        bytes memory _signature
    ) internal view returns (bool) {
        bytes32 _digest = keccak256(
            abi.encodePacked(homeDomainHash(), _oldRoot, _newRoot)
        );
        _digest = ECDSA.toEthSignedMessageHash(_digest);
        return (ECDSA.recover(_digest, _signature) == updater);
    }
    function renounceOwnership() public override onlyOwner {
    }
}