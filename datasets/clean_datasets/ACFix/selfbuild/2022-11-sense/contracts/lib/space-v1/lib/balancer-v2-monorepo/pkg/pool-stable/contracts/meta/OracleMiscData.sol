pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/WordCodec.sol";
library OracleMiscData {
    using WordCodec for bytes32;
    using WordCodec for uint256;
    uint256 private constant _LOG_INVARIANT_OFFSET = 0;
    uint256 private constant _LOG_TOTAL_SUPPLY_OFFSET = 22;
    uint256 private constant _ORACLE_SAMPLE_CREATION_TIMESTAMP_OFFSET = 44;
    uint256 private constant _ORACLE_INDEX_OFFSET = 75;
    uint256 private constant _ORACLE_ENABLED_OFFSET = 85;
    function logInvariant(bytes32 data) internal pure returns (int256) {
        return data.decodeInt22(_LOG_INVARIANT_OFFSET);
    }
    function logTotalSupply(bytes32 data) internal pure returns (int256) {
        return data.decodeInt22(_LOG_TOTAL_SUPPLY_OFFSET);
    }
    function oracleSampleCreationTimestamp(bytes32 data) internal pure returns (uint256) {
        return data.decodeUint31(_ORACLE_SAMPLE_CREATION_TIMESTAMP_OFFSET);
    }
    function oracleIndex(bytes32 data) internal pure returns (uint256) {
        return data.decodeUint10(_ORACLE_INDEX_OFFSET);
    }
    function oracleEnabled(bytes32 data) internal pure returns (bool) {
        return data.decodeBool(_ORACLE_ENABLED_OFFSET);
    }
    function setLogInvariant(bytes32 data, int256 _logInvariant) internal pure returns (bytes32) {
        return data.insertInt22(_logInvariant, _LOG_INVARIANT_OFFSET);
    }
    function setLogTotalSupply(bytes32 data, int256 _logTotalSupply) internal pure returns (bytes32) {
        return data.insertInt22(_logTotalSupply, _LOG_TOTAL_SUPPLY_OFFSET);
    }
    function setOracleSampleCreationTimestamp(bytes32 data, uint256 _initialTimestamp) internal pure returns (bytes32) {
        return data.insertUint31(_initialTimestamp, _ORACLE_SAMPLE_CREATION_TIMESTAMP_OFFSET);
    }
    function setOracleIndex(bytes32 data, uint256 _oracleIndex) internal pure returns (bytes32) {
        return data.insertUint10(_oracleIndex, _ORACLE_INDEX_OFFSET);
    }
    function setOracleEnabled(bytes32 data, bool _oracleEnabled) internal pure returns (bytes32) {
        return data.insertBool(_oracleEnabled, _ORACLE_ENABLED_OFFSET);
    }
}