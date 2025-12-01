pragma solidity ^0.8.19;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../src/utils/Errors.sol";
import "../src/ERC20Token.sol";
import "../src/TypeTokens.sol";
import "forge-std/Test.sol";
import "./utils/Functions.sol";
contract TypeTokensTest is Test {
    uint8 public constant TOKEN_TYPE_UNDEFINED = 0;
    uint8 public constant TOKEN_TYPE_STABLE = 1;
    TypeTokensHarness internal _typeTokens;
    address internal _usd1;
    address internal _usd91;
    event TokenAdded(address indexed token, uint8 tokenType);
    event TokenRemoved(address indexed token, uint8 tokenType);
    function setUp() public {
        _typeTokens = new TypeTokensHarness();
        _usd1 = address(new ERC20Token("Unitas 1", "USD1", address(this), address(this), address(this)));
        _usd91 = address(new ERC20Token("Unitas 91", "USD91", address(this), address(this), address(this)));
        vm.label(_usd1, "USD1");
        vm.label(_usd91, "USD91");
    }
    function test_listTokensByIndexAndCount_FailWhenIndexPlusCountInvalid() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 0, 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 1, 0);
        _assertAddedToken(_usd1, tokenType);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 1, 0);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 1, 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 0, 2);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 1, 2);
    }
    function test_listTokensByIndexAndCount_FailWhenIndexPlusCountInvalidAndTokensEmpty() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 0, 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _typeTokens.listTokensByIndexAndCount(tokenType, 1, 0);
    }
    function test_listTokensByIndexAndCount_WhenTokensEmpty() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        address[] memory tokens = _typeTokens.listTokensByIndexAndCount(tokenType, 0, 0);
        assertEq(tokens.length, 0, "tokens length when index 0 and size 0");
    }
    function test_listTokensByIndexAndCount_Correct() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        _assertAddedToken(_usd1, tokenType);
        address[] memory tokens = _typeTokens.listTokensByIndexAndCount(tokenType, 0, 1);
        assertEq(tokens.length, 1, "tokens length after adding usd1");
        _assertAddedToken(_usd91, tokenType);
        tokens = _typeTokens.listTokensByIndexAndCount(tokenType, 0, 2);
        assertEq(tokens.length, 2, "tokens length after adding usd91");
        assertEq(tokens[0], _usd1, "tokens 0 after adding usd91");
        assertEq(tokens[1], _usd91, "tokens 1 after adding usd91");
        _assertRemovedToken(_usd1);
        tokens = _typeTokens.listTokensByIndexAndCount(tokenType, 0, 1);
        assertEq(tokens.length, 1, "tokens length after removing usd1");
        assertEq(tokens[0], _usd91, "tokens 0 after removing usd1");
    }
    function test_isTokenInPool_Correct() public {
        assertFalse(_typeTokens.isTokenInPool(_usd1), "token in pool before adding");
        _assertAddedToken(_usd1, TOKEN_TYPE_STABLE);
    }
    function test_tokenByIndex_Correct() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        _assertAddedToken(_usd1, tokenType);
        _assertAddedToken(_usd91, tokenType);
        uint256 tokenLength = _typeTokens.tokenLength(tokenType);
        assertEq(tokenLength, 2, "token length after adding usd91");
        assertEq(_typeTokens.tokenByIndex(tokenType, 0), _usd1, "token by index 0 after adding usd91");
        assertEq(_typeTokens.tokenByIndex(tokenType, 1), _usd91, "token by index 1 after adding usd91");
        _assertRemovedToken(_usd91);
        tokenLength = _typeTokens.tokenLength(tokenType);
        assertEq(tokenLength, 1, "token length after removing usd91");
        assertEq(_typeTokens.tokenByIndex(tokenType, 0), _usd1, "token by index 0 after removing usd91");
    }
    function test_addToken_FailWhenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        _typeTokens.exposed_addToken(address(0), TOKEN_TYPE_STABLE);
    }
    function test_addToken_FailWhenTokenTypeInvalid() public {
        vm.expectRevert(_errorMessage(Errors.TOKEN_TYPE_INVALID));
        _typeTokens.exposed_addToken(_usd1, TOKEN_TYPE_UNDEFINED);
    }
    function test_addToken_FailWhenTokenInPool() public {
        _assertAddedToken(_usd1, TOKEN_TYPE_STABLE);
        vm.expectRevert(
            abi.encodeWithSignature("TokenAlreadyInPool(address)", _usd1)
        );
        _typeTokens.exposed_addToken(_usd1, TOKEN_TYPE_STABLE);
    }
    function test_addToken_Added() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        _assertAddedToken(_usd1, tokenType);
        _assertAddedToken(_usd91, tokenType);
        assertEq(_typeTokens.tokenLength(tokenType), 2, "stable token length");
    }
    function test_RemoveToken_FailWhenTokenNotInPool() public {
        vm.expectRevert(
            abi.encodeWithSignature("TokenNotInPool(address)", _usd1)
        );
        _typeTokens.exposed_removeToken(_usd1);
    }
    function test_removeToken_Removed() public {
        uint8 tokenType = TOKEN_TYPE_STABLE;
        _assertAddedToken(_usd1, tokenType);
        _assertAddedToken(_usd91, tokenType);
        _assertRemovedToken(_usd1);
        _assertRemovedToken(_usd91);
        assertEq(_typeTokens.tokenLength(tokenType), 0, "stable token length");
    }
    function _assertAddedToken(address token, uint8 tokenType) internal {
        uint256 tokenLength = _typeTokens.tokenLength(tokenType);
        vm.expectEmit(true, true, true, true, address(_typeTokens));
        emit TokenAdded(token, tokenType);
        _typeTokens.exposed_addToken(token, tokenType);
        assertTrue(_typeTokens.isTokenInPool(token), "token in pool after adding");
        assertTrue(_typeTokens.exposed_typeTokens_contains(tokenType, token), "token in list after adding");
        assertEq(_typeTokens.exposed_tokenType(token), tokenType, "token type after adding");
        assertEq(_typeTokens.tokenLength(tokenType), tokenLength + 1, "token length after adding");
    }
    function _assertRemovedToken(address token) internal {
        uint8 tokenType = _typeTokens.exposed_tokenType(token);
        uint256 tokenLength = _typeTokens.tokenLength(tokenType);
        vm.expectEmit(true, true, true, true, address(_typeTokens));
        emit TokenRemoved(token, tokenType);
        _typeTokens.exposed_removeToken(token);
        assertFalse(_typeTokens.isTokenInPool(token), "token in pool after removing");
        assertFalse(_typeTokens.exposed_typeTokens_contains(tokenType, token), "token in list after removing");
        assertEq(_typeTokens.exposed_tokenType(token), TOKEN_TYPE_UNDEFINED, "token type after removing");
        assertEq(_typeTokens.tokenLength(tokenType), tokenLength - 1, "token length after removing");
    }
}
contract TypeTokensHarness is TypeTokens {
    using EnumerableSet for EnumerableSet.AddressSet;
    function exposed_addToken(address token, uint8 tokenType) external {
        return _addToken(token, tokenType);
    }
    function exposed_removeToken(address token) external {
        return _removeToken(token);
    }
    function exposed_tokenType(address token) external view returns (uint8) {
        return _tokenType[token];
    }
    function exposed_typeTokens_contains(uint8 tokenType, address token) external view returns (bool) {
        return _typeTokens[tokenType].contains(token);
    }
    function _isTokenTypeValid(uint8 tokenType) internal pure virtual override returns (bool) {
        return tokenType > 0;
    }
}