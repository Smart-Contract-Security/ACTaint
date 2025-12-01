pragma solidity ^0.8.19;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITypeTokens.sol";
import "./utils/AddressUtils.sol";
import "./utils/Errors.sol";
abstract contract TypeTokens is ITypeTokens {
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(address => uint8) internal _tokenType;
    mapping(uint8 => EnumerableSet.AddressSet) internal _typeTokens;
    event TokenAdded(address indexed token, uint8 tokenType);
    event TokenRemoved(address indexed token, uint8 tokenType);
    error TokenNotInPool(address token);
    error TokenAlreadyInPool(address token);
    modifier tokenInPool(address token) {
        if (!isTokenInPool(token))
            revert TokenNotInPool(token);
        _;
    }
    modifier tokenNotInPool(address token) {
        if (isTokenInPool(token))
            revert TokenAlreadyInPool(token);
        _;
    }
    function listTokensByIndexAndCount(uint8 tokenType, uint256 index, uint256 count) external view virtual returns (address[] memory) {
        EnumerableSet.AddressSet storage tokenSet = _typeTokens[tokenType];
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
    function isTokenInPool(address token) public view virtual returns (bool) {
        return _isTokenTypeValid(_tokenType[token]);
    }
    function tokenLength(uint8 tokenType) public view virtual returns (uint256) {
        return _typeTokens[tokenType].length();
    }
    function tokenByIndex(uint8 tokenType, uint256 index) public view virtual returns (address) {
        return _typeTokens[tokenType].at(index);
    }
    function _addToken(address token, uint8 tokenType) internal virtual tokenNotInPool(token) {
        AddressUtils.checkContract(token);
        _require(_isTokenTypeValid(tokenType), Errors.TOKEN_TYPE_INVALID);
        _require(_typeTokens[tokenType].add(token), Errors.TOKEN_ALREADY_EXISTS);
        _tokenType[token] = tokenType;
        emit TokenAdded(token, tokenType);
    }
    function _removeToken(address token) internal virtual tokenInPool(token) {
        uint8 tokenType = _tokenType[token];
        _require(_typeTokens[tokenType].remove(token), Errors.TOKEN_NOT_EXISTS);
        delete (_tokenType[token]);
        emit TokenRemoved(token, tokenType);
    }
    function _isTokenTypeValid(uint8 tokenType) internal pure virtual returns (bool);
}