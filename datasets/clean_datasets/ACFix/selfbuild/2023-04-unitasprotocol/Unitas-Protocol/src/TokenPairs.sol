pragma solidity ^0.8.19;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITokenPairs.sol";
import "./utils/Errors.sol";
abstract contract TokenPairs is ITokenPairs {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    mapping(address => EnumerableSet.AddressSet) internal _pairTokens;
    EnumerableSet.Bytes32Set internal _pairHashes;
    event PairAdded(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    event PairRemoved(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    function listPairTokensByIndexAndCount(address token, uint256 index, uint256 count) external view virtual returns (address[] memory) {
        EnumerableSet.AddressSet storage tokenSet = _pairTokens[token];
        uint256 tokenCount = tokenSet.length();
        _require(
            (index == 0 || index < tokenCount) && index + count <= tokenCount,
            Errors.INPUT_OUT_OF_BOUNDS
        );
        address[] memory tokens = new address[](count);
        for (uint256 i; i < count; i++) {
            tokens[i] = tokenSet.at(index + i);
        }
        return tokens;
    }
    function isPairInPool(address tokenX, address tokenY) public view virtual returns (bool) {
        return _pairHashes.contains(getPairHash(tokenX, tokenY));
    }
    function pairTokenLength(address token) public view virtual returns (uint256) {
        return _pairTokens[token].length();
    }
    function pairTokenByIndex(address token, uint256 index) public view returns (address) {
        return _pairTokens[token].at(index);
    }
    function pairLength() public view virtual returns (uint256) {
        return _pairHashes.length();
    }
    function getPairHash(address tokenX, address tokenY) public pure virtual returns (bytes32) {
        (tokenX, tokenY) = _sortTokens(tokenX, tokenY);
        return _getPairHash(tokenX, tokenY);
    }
    function _addPairByTokens(address tokenX, address tokenY) internal virtual returns (bytes32) {
        _require(tokenX < tokenY, Errors.TOKENS_NOT_SORTED);
        bytes32 pairHash = _getPairHash(tokenX, tokenY);
        _require(_pairHashes.add(pairHash), Errors.PAIR_ALREADY_EXISTS);
        _require(
            _pairTokens[tokenX].add(tokenY) && _pairTokens[tokenY].add(tokenX),
            Errors.PAIR_ALREADY_EXISTS
        );
        emit PairAdded(pairHash, tokenX, tokenY);
        return pairHash;
    }
    function _removePairByTokens(address tokenX, address tokenY) internal virtual returns (bytes32) {
        bytes32 pairHash = _getPairHash(tokenX, tokenY);
        _require(_pairHashes.remove(pairHash), Errors.PAIR_NOT_EXISTS);
        _require(
            _pairTokens[tokenX].remove(tokenY) && _pairTokens[tokenY].remove(tokenX),
            Errors.PAIR_NOT_EXISTS
        );
        emit PairRemoved(pairHash, tokenX, tokenY);
        return pairHash;
    }
    function _checkPairExists(address tokenX, address tokenY) internal view virtual returns (bytes32) {
        bytes32 pairHash = _getPairHash(tokenX, tokenY);
        _require(_pairHashes.contains(pairHash), Errors.PAIR_NOT_EXISTS);
        return pairHash;
    }
    function _getPairHash(address tokenX, address tokenY) internal pure virtual returns (bytes32) {
        return keccak256(abi.encode(tokenX, tokenY));
    }
    function _sortTokens(address tokenX, address tokenY) internal pure virtual returns (address, address) {
        return tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
    }
}