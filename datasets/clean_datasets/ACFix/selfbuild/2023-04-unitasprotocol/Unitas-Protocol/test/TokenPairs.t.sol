pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../src/interfaces/IERC20Token.sol";
import "../src/utils/Errors.sol";
import "../src/TokenPairs.sol";
import "../src/ERC20Token.sol";
import "./mocks/MockERC20Token.sol";
import "./utils/Functions.sol";
contract TokenPairsTest is Test {
    IERC20Token internal _usd1;
    IERC20Token internal _usd91;
    IERC20Token internal _usd971;
    MockERC20Token internal _usdt;
    TokenPairsHarness internal _tokenPairs;
    event PairAdded(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    event PairRemoved(bytes32 indexed pairHash, address indexed tokenX, address indexed tokenY);
    function setUp() public {
        _usd1 = _deployUnitasERC20Token("Unitas 1", "USD1");
        _usd91 = _deployUnitasERC20Token("Unitas 91", "USD91");
        _usd971 = _deployUnitasERC20Token("Unitas 971", "USD971");
        _usdt = new MockERC20Token("Tether USD", "USDT", 6);
        _tokenPairs = new TokenPairsHarness();
        vm.label(address(_usd1), "USD1");
        vm.label(address(_usd91), "USD91");
        vm.label(address(_usd971), "USD971");
        vm.label(address(_usdt), "USDT");
    }
    function test_listPairTokensByIndexAndCount_FailWhenIndexPlusCountInvalid() public {
        address tokenX;
        address tokenY;
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usdt));
        _assertPairAdded(tokenX, tokenY);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usd91));
        _assertPairAdded(tokenX, tokenY);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usd971));
        _assertPairAdded(tokenX, tokenY);
        uint256 tokenCount = _tokenPairs.pairTokenLength(address(_usd1));
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenPairs.listPairTokensByIndexAndCount(address(_usd1), tokenCount, 0);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenPairs.listPairTokensByIndexAndCount(address(_usd1), 0, tokenCount + 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenPairs.listPairTokensByIndexAndCount(address(_usd1), tokenCount - 1, 2);
    }
    function test_listPairsByIndexAndCount_FailWhenPairTokensEmpty() public {
        address token = vm.addr(0x10001);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenPairs.listPairTokensByIndexAndCount(token, 0, 1);
        vm.expectRevert(_errorMessage(Errors.INPUT_OUT_OF_BOUNDS));
        _tokenPairs.listPairTokensByIndexAndCount(token, 1, 0);
    }
    function test_listPairTokensByIndexAndCount_WhenPairTokensEmpty() public {
        address token = vm.addr(0x10001);
        address[] memory tokens = _tokenPairs.listPairTokensByIndexAndCount(token, 0, 0);
        assertEq(tokens.length, 0, "tokens length when index 0 and size 0");
    }
    function test_listPairTokensByIndexAndCount_Correct() public {
        address tokenX;
        address tokenY;
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usdt));
        _assertPairAdded(tokenX, tokenY);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usd91));
        _assertPairAdded(tokenX, tokenY);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usd971));
        _assertPairAdded(tokenX, tokenY);
        address[] memory tokens = _tokenPairs.listPairTokensByIndexAndCount(address(_usd1), 0, 3);
        assertEq(tokens.length, 3, "tokens length after adding 3 pairs");
        assertEq(tokens[0], address(_usdt), "tokens 0 after adding 3 pairs");
        assertEq(tokens[1], address(_usd91), "tokens 1 after adding 3 pairs");
        assertEq(tokens[2], address(_usd971), "tokens 2 after adding 3 pairs");
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usdt));
        _assertPairRemoved(tokenX, tokenY);
        tokens = _tokenPairs.listPairTokensByIndexAndCount(address(_usd1), 0, 2);
        assertEq(tokens.length, 2, "tokens length after removing usdt");
        assertEq(tokens[0], address(_usd971), "tokens 0 after removing usdt");
        assertEq(tokens[1], address(_usd91), "tokens 1 after removing usdt");
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(address(_usd1), address(_usd971));
        _assertPairRemoved(tokenX, tokenY);
        tokens = _tokenPairs.listPairTokensByIndexAndCount(address(_usd1), 0, 1);
        assertEq(tokens.length, 1, "tokens length after removing usd971");
        assertEq(tokens[0], address(_usd91), "tokens 0 after removing usd971");
    }
    function test_addPairByTokens_FailWhenExists() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        _assertPairAdded(tokenX, tokenY);
        vm.expectRevert(_errorMessage(Errors.PAIR_ALREADY_EXISTS));
        _tokenPairs.exposed_addPairByTokens(tokenX, tokenY);
    }
    function test_addPairByTokens_FailWhenNotSorted() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        vm.expectRevert(_errorMessage(Errors.TOKENS_NOT_SORTED));
        _tokenPairs.exposed_addPairByTokens(tokenY, tokenX);
    }
    function test_addPairByTokens_Added() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        _assertPairAdded(tokenX, tokenY);
    }
    function test_removePairByTokens_FailWhenNotExists() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        vm.expectRevert(_errorMessage(Errors.PAIR_NOT_EXISTS));
        _tokenPairs.exposed_removePairByTokens(tokenX, tokenY);
    }
    function test_removePairByTokens_FailWhenNotSorted() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        _assertPairAdded(tokenX, tokenY);
        vm.expectRevert(_errorMessage(Errors.PAIR_NOT_EXISTS));
        _tokenPairs.exposed_removePairByTokens(tokenY, tokenX);
    }
    function test_removePairByTokens_Removed() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        _assertPairAdded(tokenX, tokenY);
        _assertPairRemoved(tokenX, tokenY);
    }
    function test_checkPairExists_FailWhenNotExists() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        vm.expectRevert(_errorMessage(Errors.PAIR_NOT_EXISTS));
        _tokenPairs.exposed_checkPairExists(tokenX, tokenY);
    }
    function test_checkPairExists_FailWhenNotSorted() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        _assertPairAdded(tokenX, tokenY);
        vm.expectRevert(_errorMessage(Errors.PAIR_NOT_EXISTS));
        _tokenPairs.exposed_checkPairExists(tokenY, tokenX);
    }
    function test_checkPairExists_Correct() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        _assertPairAdded(tokenX, tokenY);
        bytes32 pairHash = _tokenPairs.exposed_checkPairExists(tokenX, tokenY);
        assertEq(pairHash, keccak256(abi.encode(tokenX, tokenY)), "pair hash");
    }
    function test_getPairHash_Correct() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        bytes32 pairHash = _tokenPairs.exposed_getPairHash(tokenX, tokenY);
        assertEq(pairHash, keccak256(abi.encode(tokenX, tokenY)), "pair hash");
        assertEq(pairHash, _tokenPairs.getPairHash(tokenX, tokenY), "pair hash getter");
        assertEq(pairHash, _tokenPairs.getPairHash(tokenY, tokenX), "pair hash getter reverse");
        pairHash = _tokenPairs.exposed_getPairHash(tokenY, tokenX);
        assertNotEq(pairHash, keccak256(abi.encode(tokenX, tokenY)), "pair hash reverse");
    }
    function test_sortTokens_WhenTokensSame() public {
        address tokenX = address(0x0);
        address tokenY = address(0x0);
        (address resultX, address resultY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        assertEq(resultX, tokenX, "token x");
        assertEq(resultY, tokenY, "token y");
    }
    function test_sortTokens_Correct() public {
        address tokenX = vm.addr(0x10001);
        address tokenY = vm.addr(0x10002);
        (tokenX, tokenY) = tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
        (address resultX, address resultY) = _tokenPairs.exposed_sortTokens(tokenX, tokenY);
        assertEq(resultX, tokenX, "token x");
        assertEq(resultY, tokenY, "token y");
        (resultX, resultY) = _tokenPairs.exposed_sortTokens(tokenY, tokenX);
        assertEq(resultX, tokenX, "token x");
        assertEq(resultY, tokenY, "token y");
    }
    function _assertPairAdded(address tokenX, address tokenY) internal {
        uint256 pairCount = _tokenPairs.pairLength();
        uint256 xPairTokenCount = _tokenPairs.pairTokenLength(tokenX);
        uint256 yPairTokenCount = _tokenPairs.pairTokenLength(tokenY);
        vm.expectEmit(true, true, true, true, address(_tokenPairs));
        emit PairAdded(keccak256(abi.encode(tokenX, tokenY)), tokenX, tokenY);
        bytes32 pairHash = _tokenPairs.exposed_addPairByTokens(tokenX, tokenY);
        assertEq(_tokenPairs.pairLength(), pairCount + 1, "pair count");
        assertTrue(_tokenPairs.isPairInPool(tokenX, tokenY), "pair in pool");
        assertEq(_tokenPairs.pairTokenLength(tokenX), xPairTokenCount + 1, "x pair token count");
        assertEq(_tokenPairs.pairTokenLength(tokenY), yPairTokenCount + 1, "y pair token count");
        assertEq(_tokenPairs.pairTokenByIndex(tokenX, xPairTokenCount), tokenY, "x pair token by index");
        assertEq(_tokenPairs.pairTokenByIndex(tokenY, yPairTokenCount), tokenX, "y pair token by index");
        assertEq(pairHash, keccak256(abi.encode(tokenX, tokenY)), "pair hash");
        assertEq(pairHash, _tokenPairs.getPairHash(tokenX, tokenY), "pair hash getter");
    }
    function _assertPairRemoved(address tokenX, address tokenY) internal {
        uint256 pairCount = _tokenPairs.pairLength();
        uint256 xPairTokenCount = _tokenPairs.pairTokenLength(tokenX);
        uint256 yPairTokenCount = _tokenPairs.pairTokenLength(tokenY);
        vm.expectEmit(true, true, true, true, address(_tokenPairs));
        emit PairRemoved(keccak256(abi.encode(tokenX, tokenY)), tokenX, tokenY);
        _tokenPairs.exposed_removePairByTokens(tokenX, tokenY);
        assertEq(_tokenPairs.pairLength(), pairCount - 1, "pair count");
        assertFalse(_tokenPairs.isPairInPool(tokenX, tokenY), "pair in pool");
        assertEq(_tokenPairs.pairTokenLength(tokenX), xPairTokenCount - 1, "x pair token count");
        assertEq(_tokenPairs.pairTokenLength(tokenY), yPairTokenCount - 1, "y pair token count");
    }
    function _deployUnitasERC20Token(string memory name, string memory symbol) internal returns (IERC20Token) {
        ERC20Token token = new ERC20Token(name, symbol, address(this), address(this), address(this));
        return IERC20Token(address(token));
    }
}
contract TokenPairsHarness is TokenPairs {
    constructor() {}
    function exposed_addPairByTokens(address tokenX, address tokenY) external returns (bytes32) {
        return _addPairByTokens(tokenX, tokenY);
    }
    function exposed_removePairByTokens(address tokenX, address tokenY) external returns (bytes32) {
        return _removePairByTokens(tokenX, tokenY);
    }
    function exposed_checkPairExists(address tokenX, address tokenY) external view returns (bytes32) {
        return _checkPairExists(tokenX, tokenY);
    }
    function exposed_getPairHash(address tokenX, address tokenY) external pure returns (bytes32) {
        return _getPairHash(tokenX, tokenY);
    }
    function exposed_sortTokens(address tokenX, address tokenY) external pure returns (address, address) {
        return _sortTokens(tokenX, tokenY);
    }
}