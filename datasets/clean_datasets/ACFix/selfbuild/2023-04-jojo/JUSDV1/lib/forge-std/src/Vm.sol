pragma solidity >=0.6.2 <0.9.0;
pragma experimental ABIEncoderV2;
interface VmSafe {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    struct Rpc {
        string key;
        string url;
    }
    struct FsMetadata {
        bool isDir;
        bool isSymlink;
        uint256 length;
        bool readOnly;
        uint256 modified;
        uint256 accessed;
        uint256 created;
    }
    function load(address target, bytes32 slot) external view returns (bytes32 data);
    function sign(uint256 privateKey, bytes32 digest) external pure returns (uint8 v, bytes32 r, bytes32 s);
    function addr(uint256 privateKey) external pure returns (address keyAddr);
    function getNonce(address account) external view returns (uint64 nonce);
    function ffi(string[] calldata commandInput) external returns (bytes memory result);
    function setEnv(string calldata name, string calldata value) external;
    function envBool(string calldata name) external view returns (bool value);
    function envUint(string calldata name) external view returns (uint256 value);
    function envInt(string calldata name) external view returns (int256 value);
    function envAddress(string calldata name) external view returns (address value);
    function envBytes32(string calldata name) external view returns (bytes32 value);
    function envString(string calldata name) external view returns (string memory value);
    function envBytes(string calldata name) external view returns (bytes memory value);
    function envBool(string calldata name, string calldata delim) external view returns (bool[] memory value);
    function envUint(string calldata name, string calldata delim) external view returns (uint256[] memory value);
    function envInt(string calldata name, string calldata delim) external view returns (int256[] memory value);
    function envAddress(string calldata name, string calldata delim) external view returns (address[] memory value);
    function envBytes32(string calldata name, string calldata delim) external view returns (bytes32[] memory value);
    function envString(string calldata name, string calldata delim) external view returns (string[] memory value);
    function envBytes(string calldata name, string calldata delim) external view returns (bytes[] memory value);
    function envOr(string calldata name, bool defaultValue) external returns (bool value);
    function envOr(string calldata name, uint256 defaultValue) external returns (uint256 value);
    function envOr(string calldata name, int256 defaultValue) external returns (int256 value);
    function envOr(string calldata name, address defaultValue) external returns (address value);
    function envOr(string calldata name, bytes32 defaultValue) external returns (bytes32 value);
    function envOr(string calldata name, string calldata defaultValue) external returns (string memory value);
    function envOr(string calldata name, bytes calldata defaultValue) external returns (bytes memory value);
    function envOr(string calldata name, string calldata delim, bool[] calldata defaultValue)
        external
        returns (bool[] memory value);
    function envOr(string calldata name, string calldata delim, uint256[] calldata defaultValue)
        external
        returns (uint256[] memory value);
    function envOr(string calldata name, string calldata delim, int256[] calldata defaultValue)
        external
        returns (int256[] memory value);
    function envOr(string calldata name, string calldata delim, address[] calldata defaultValue)
        external
        returns (address[] memory value);
    function envOr(string calldata name, string calldata delim, bytes32[] calldata defaultValue)
        external
        returns (bytes32[] memory value);
    function envOr(string calldata name, string calldata delim, string[] calldata defaultValue)
        external
        returns (string[] memory value);
    function envOr(string calldata name, string calldata delim, bytes[] calldata defaultValue)
        external
        returns (bytes[] memory value);
    function record() external;
    function accesses(address target) external returns (bytes32[] memory readSlots, bytes32[] memory writeSlots);
    function getCode(string calldata artifactPath) external view returns (bytes memory creationBytecode);
    function getDeployedCode(string calldata artifactPath) external view returns (bytes memory runtimeBytecode);
    function label(address account, string calldata newLabel) external;
    function broadcast() external;
    function broadcast(address signer) external;
    function broadcast(uint256 privateKey) external;
    function startBroadcast() external;
    function startBroadcast(address signer) external;
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function readFile(string calldata path) external view returns (string memory data);
    function readFileBinary(string calldata path) external view returns (bytes memory data);
    function projectRoot() external view returns (string memory path);
    function fsMetadata(string calldata fileOrDir) external returns (FsMetadata memory metadata);
    function readLine(string calldata path) external view returns (string memory line);
    function writeFile(string calldata path, string calldata data) external;
    function writeFileBinary(string calldata path, bytes calldata data) external;
    function writeLine(string calldata path, string calldata data) external;
    function closeFile(string calldata path) external;
    function removeFile(string calldata path) external;
    function toString(address value) external pure returns (string memory stringifiedValue);
    function toString(bytes calldata value) external pure returns (string memory stringifiedValue);
    function toString(bytes32 value) external pure returns (string memory stringifiedValue);
    function toString(bool value) external pure returns (string memory stringifiedValue);
    function toString(uint256 value) external pure returns (string memory stringifiedValue);
    function toString(int256 value) external pure returns (string memory stringifiedValue);
    function parseBytes(string calldata stringifiedValue) external pure returns (bytes memory parsedValue);
    function parseAddress(string calldata stringifiedValue) external pure returns (address parsedValue);
    function parseUint(string calldata stringifiedValue) external pure returns (uint256 parsedValue);
    function parseInt(string calldata stringifiedValue) external pure returns (int256 parsedValue);
    function parseBytes32(string calldata stringifiedValue) external pure returns (bytes32 parsedValue);
    function parseBool(string calldata stringifiedValue) external pure returns (bool parsedValue);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory logs);
    function deriveKey(string calldata mnemonic, uint32 index) external pure returns (uint256 privateKey);
    function deriveKey(string calldata mnemonic, string calldata derivationPath, uint32 index)
        external
        pure
        returns (uint256 privateKey);
    function rememberKey(uint256 privateKey) external returns (address keyAddr);
    function parseJson(string calldata json, string calldata key) external pure returns (bytes memory abiEncodedData);
    function parseJson(string calldata json) external pure returns (bytes memory abiEncodedData);
    function parseJsonUint(string calldata, string calldata) external returns (uint256);
    function parseJsonUintArray(string calldata, string calldata) external returns (uint256[] memory);
    function parseJsonInt(string calldata, string calldata) external returns (int256);
    function parseJsonIntArray(string calldata, string calldata) external returns (int256[] memory);
    function parseJsonBool(string calldata, string calldata) external returns (bool);
    function parseJsonBoolArray(string calldata, string calldata) external returns (bool[] memory);
    function parseJsonAddress(string calldata, string calldata) external returns (address);
    function parseJsonAddressArray(string calldata, string calldata) external returns (address[] memory);
    function parseJsonString(string calldata, string calldata) external returns (string memory);
    function parseJsonStringArray(string calldata, string calldata) external returns (string[] memory);
    function parseJsonBytes(string calldata, string calldata) external returns (bytes memory);
    function parseJsonBytesArray(string calldata, string calldata) external returns (bytes[] memory);
    function parseJsonBytes32(string calldata, string calldata) external returns (bytes32);
    function parseJsonBytes32Array(string calldata, string calldata) external returns (bytes32[] memory);
    function serializeBool(string calldata objectKey, string calldata valueKey, bool value)
        external
        returns (string memory json);
    function serializeUint(string calldata objectKey, string calldata valueKey, uint256 value)
        external
        returns (string memory json);
    function serializeInt(string calldata objectKey, string calldata valueKey, int256 value)
        external
        returns (string memory json);
    function serializeAddress(string calldata objectKey, string calldata valueKey, address value)
        external
        returns (string memory json);
    function serializeBytes32(string calldata objectKey, string calldata valueKey, bytes32 value)
        external
        returns (string memory json);
    function serializeString(string calldata objectKey, string calldata valueKey, string calldata value)
        external
        returns (string memory json);
    function serializeBytes(string calldata objectKey, string calldata valueKey, bytes calldata value)
        external
        returns (string memory json);
    function serializeBool(string calldata objectKey, string calldata valueKey, bool[] calldata values)
        external
        returns (string memory json);
    function serializeUint(string calldata objectKey, string calldata valueKey, uint256[] calldata values)
        external
        returns (string memory json);
    function serializeInt(string calldata objectKey, string calldata valueKey, int256[] calldata values)
        external
        returns (string memory json);
    function serializeAddress(string calldata objectKey, string calldata valueKey, address[] calldata values)
        external
        returns (string memory json);
    function serializeBytes32(string calldata objectKey, string calldata valueKey, bytes32[] calldata values)
        external
        returns (string memory json);
    function serializeString(string calldata objectKey, string calldata valueKey, string[] calldata values)
        external
        returns (string memory json);
    function serializeBytes(string calldata objectKey, string calldata valueKey, bytes[] calldata values)
        external
        returns (string memory json);
    function writeJson(string calldata json, string calldata path) external;
    function writeJson(string calldata json, string calldata path, string calldata valueKey) external;
    function rpcUrl(string calldata rpcAlias) external view returns (string memory json);
    function rpcUrls() external view returns (string[2][] memory urls);
    function rpcUrlStructs() external view returns (Rpc[] memory urls);
    function assume(bool condition) external pure;
    function pauseGasMetering() external;
    function resumeGasMetering() external;
    function breakpoint(string calldata char) external;
}
interface Vm is VmSafe {
    function warp(uint256 newTimestamp) external;
    function roll(uint256 newHeight) external;
    function fee(uint256 newBasefee) external;
    function difficulty(uint256 newDifficulty) external;
    function chainId(uint256 newChainId) external;
    function txGasPrice(uint256 newGasPrice) external;
    function store(address target, bytes32 slot, bytes32 value) external;
    function setNonce(address account, uint64 newNonce) external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function prank(address msgSender, address txOrigin) external;
    function startPrank(address msgSender, address txOrigin) external;
    function stopPrank() external;
    function deal(address account, uint256 newBalance) external;
    function etch(address target, bytes calldata newRuntimeBytecode) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert() external;
    function expectEmit() external;
    function expectEmit(address emitter) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData, address emitter)
        external;
    function mockCall(address callee, bytes calldata data, bytes calldata returnData) external;
    function mockCall(address callee, uint256 msgValue, bytes calldata data, bytes calldata returnData) external;
    function mockCallRevert(address callee, bytes calldata data, bytes calldata revertData) external;
    function mockCallRevert(address callee, uint256 msgValue, bytes calldata data, bytes calldata revertData)
        external;
    function clearMockedCalls() external;
    function expectCall(address callee, bytes calldata data) external;
    function expectCall(address callee, uint256 msgValue, bytes calldata data) external;
    function expectCall(address callee, uint256 msgValue, uint64 gas, bytes calldata data) external;
    function expectCallMinGas(address callee, uint256 msgValue, uint64 minGas, bytes calldata data) external;
    function expectSafeMemory(uint64 min, uint64 max) external;
    function expectSafeMemoryCall(uint64 min, uint64 max) external;
    function coinbase(address newCoinbase) external;
    function snapshot() external returns (uint256 snapshotId);
    function revertTo(uint256 snapshotId) external returns (bool success);
    function createFork(string calldata urlOrAlias, uint256 blockNumber) external returns (uint256 forkId);
    function createFork(string calldata urlOrAlias) external returns (uint256 forkId);
    function createFork(string calldata urlOrAlias, bytes32 txHash) external returns (uint256 forkId);
    function createSelectFork(string calldata urlOrAlias, uint256 blockNumber) external returns (uint256 forkId);
    function createSelectFork(string calldata urlOrAlias, bytes32 txHash) external returns (uint256 forkId);
    function createSelectFork(string calldata urlOrAlias) external returns (uint256 forkId);
    function selectFork(uint256 forkId) external;
    function activeFork() external view returns (uint256 forkId);
    function rollFork(uint256 blockNumber) external;
    function rollFork(bytes32 txHash) external;
    function rollFork(uint256 forkId, uint256 blockNumber) external;
    function rollFork(uint256 forkId, bytes32 txHash) external;
    function makePersistent(address account) external;
    function makePersistent(address account0, address account1) external;
    function makePersistent(address account0, address account1, address account2) external;
    function makePersistent(address[] calldata accounts) external;
    function revokePersistent(address account) external;
    function revokePersistent(address[] calldata accounts) external;
    function isPersistent(address account) external view returns (bool persistent);
    function allowCheatcodes(address account) external;
    function transact(bytes32 txHash) external;
    function transact(uint256 forkId, bytes32 txHash) external;
}