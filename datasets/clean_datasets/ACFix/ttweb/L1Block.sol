pragma solidity 0.8.15;
import { Semver } from "../universal/Semver.sol";
contract L1Block is Semver {
    address public constant DEPOSITOR_ACCOUNT = 0xDeaDDEaDDeAdDeAdDEAdDEaddeAddEAdDEAd0001;
    uint64 public number;
    uint64 public timestamp;
    uint256 public basefee;
    bytes32 public hash;
    uint64 public sequenceNumber;
    bytes32 public batcherHash;
    uint256 public l1FeeOverhead;
    uint256 public l1FeeScalar;
    constructor() Semver(1, 0, 0) {}
    function setL1BlockValues(
        uint64 _number,
        uint64 _timestamp,
        uint256 _basefee,
        bytes32 _hash,
        uint64 _sequenceNumber,
        bytes32 _batcherHash,
        uint256 _l1FeeOverhead,
        uint256 _l1FeeScalar
    ) external {
        require(
            msg.sender == DEPOSITOR_ACCOUNT,
            "L1Block: only the depositor account can set L1 block values"
        );
        number = _number;
        timestamp = _timestamp;
        basefee = _basefee;
        hash = _hash;
        sequenceNumber = _sequenceNumber;
        batcherHash = _batcherHash;
        l1FeeOverhead = _l1FeeOverhead;
        l1FeeScalar = _l1FeeScalar;
    }
}