pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/utils/Errors.sol";
import "../src/PoolBalances.sol";
import "./mocks/MockERC20Token.sol";
import "./utils/Functions.sol";
contract PoolBalancesTest is Test {
    PoolBalancesHarness internal _poolBalances;
    address internal _usdt;
    event BalanceUpdated(address indexed token, uint256 newBalance);
    event PortfolioReceived(address indexed token, address indexed sender, uint256 amount);
    event PortfolioSent(address indexed token, address indexed receiver, uint256 amount);
    event PortfolioUpdated(address indexed token, uint256 newPortfolio);
    function setUp() public {
        _poolBalances = new PoolBalancesHarness();
        _usdt = address(new MockERC20Token("Tether USD", "USDT", 6));
        vm.label(_usdt, "USDT");
    }
    function test_setBalance() public {
        _assertSetBalance(_usdt, 100e6);
    }
    function test_setPortfolio() public {
        _assertSetPortfolio(_usdt, 100e6);
    }
    function test_receivePortfolio_FailWhenTokenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        _poolBalances.exposed_receivePortfolio(address(0x0), address(this), 1e6);
    }
    function test_sendPortfolio_FailWhenSenderAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        _poolBalances.exposed_receivePortfolio(_usdt, address(0x0), 1e6);
    }
    function test_receivePortfolio_FailWhenAmountZero() public {
        vm.expectRevert(_errorMessage(Errors.AMOUNT_INVALID));
        _poolBalances.exposed_receivePortfolio(_usdt, address(this), 0);
    }
    function test_receivePortfolio_FailWhenSenderInvalid() public {
        vm.expectRevert(_errorMessage(Errors.SENDER_INVALID));
        _poolBalances.exposed_receivePortfolio(_usdt, address(_poolBalances), 1e6);
    }
    function test_receivePortfolio_FailWhenAmountOverPortfolio() public {
        bytes memory message = _errorMessage(Errors.AMOUNT_INVALID);
        uint256 amount = 100e6;
        vm.expectRevert(message);
        _poolBalances.exposed_receivePortfolio(_usdt, address(this), amount);
        _assertBalanceDeposited(_usdt, address(this), amount);
        _assertSentPortfolio(_usdt, address(this), amount);
        deal(_usdt, address(this), amount + 1);
        vm.expectRevert(message);
        _poolBalances.exposed_receivePortfolio(_usdt, address(this), amount + 1);
    }
    function test_receivePortfolio_FailWhenInsufficientAllowance() public {
        uint256 amount = 100e6;
        _assertBalanceDeposited(_usdt, address(this), amount);
        _assertSentPortfolio(_usdt, address(this), amount);
        deal(_usdt, address(this), amount);
        vm.expectRevert("ERC20: insufficient allowance");
        _poolBalances.exposed_receivePortfolio(_usdt, address(this), amount);
    }
    function test_receivePortfolio_FailWhenInsufficientBalance() public {
        uint256 amount = 100e6;
        _assertBalanceDeposited(_usdt, address(this), amount);
        _assertSentPortfolio(_usdt, address(this), amount);
        deal(_usdt, address(this), amount - 1);
        IERC20(_usdt).approve(address(_poolBalances), type(uint256).max);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        _poolBalances.exposed_receivePortfolio(_usdt, address(this), amount);
    }
    function test_receivePortfolio_Received() public {
        uint256 amount = 100e6;
        _assertBalanceDeposited(_usdt, address(this), amount);
        _assertSentPortfolio(_usdt, address(this), amount);
        _assertReceivedPortfolio(_usdt, address(this), amount);
    }
    function test_sendPortfolio_FailWhenTokenAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        _poolBalances.exposed_sendPortfolio(address(0x0), address(this), 1e6);
    }
    function test_sendPortfolio_FailWhenReceiverAddressZero() public {
        vm.expectRevert(_errorMessage(Errors.ADDRESS_ZERO));
        _poolBalances.exposed_sendPortfolio(_usdt, address(0x0), 1e6);
    }
    function test_sendPortfolio_FailWhenAmountZero() public {
        vm.expectRevert(_errorMessage(Errors.AMOUNT_INVALID));
        _poolBalances.exposed_sendPortfolio(_usdt, address(this), 0);
    }
    function test_sendPortfolio_FailWhenReceiverInvalid() public {
        vm.expectRevert(_errorMessage(Errors.RECEIVER_INVALID));
        _poolBalances.exposed_sendPortfolio(_usdt, address(_poolBalances), 1e6);
    }
    function test_sendPortfolio_FailWhenBalanceEmpty() public {
        vm.expectRevert(_errorMessage(Errors.POOL_BALANCE_INSUFFICIENT));
        _poolBalances.exposed_sendPortfolio(_usdt, address(this), 100e6);
    }
    function test_sendPortfolio_FailWhenInsufficientPoolBalance() public {
        uint256 amount = 100e6;
        _assertBalanceDeposited(_usdt, address(this), amount);
        _assertSentPortfolio(_usdt, address(this), amount);
        vm.expectRevert(_errorMessage(Errors.POOL_BALANCE_INSUFFICIENT));
        _poolBalances.exposed_sendPortfolio(_usdt, address(this), 1);
    }
    function test_sendPortfolio_Sent() public {
        uint256 balanceAmount = 100e6;
        uint256 portfolioAmount = 50e6;
        _assertBalanceDeposited(_usdt, address(this), balanceAmount);
        _assertSentPortfolio(_usdt, address(this), portfolioAmount);
    }
    function test_sendPortfolio_SentWhenAmountGreaterThanPoolBalance() public {
        uint256 balanceAmount = 100e6;
        _assertBalanceDeposited(_usdt, address(this), balanceAmount);
        _assertSentPortfolio(_usdt, address(this), balanceAmount * 2, balanceAmount);
    }
    function test_checkAmountPositive_FailWhenZero() public {
        vm.expectRevert(_errorMessage(Errors.AMOUNT_INVALID));
        _poolBalances.exposed_checkAmountPositive(0);
    }
    function test_checkAmountPositive_Valid() public view {
        _poolBalances.exposed_checkAmountPositive(1);
        _poolBalances.exposed_checkAmountPositive(type(uint128).max);
        _poolBalances.exposed_checkAmountPositive(type(uint256).max);
    }
    function testFuzz_setBalance(uint256 amount) public {
        _assertSetBalance(_usdt, amount);
    }
    function testFuzz_setPortfolio(uint256 amount) public {
        _assertSetPortfolio(_usdt, amount);
    }
    function testFuzz_receivePortfolio_Received(uint256 balanceAmount, uint256 portfolioAmount, uint256 receiveAmount, address account) public {
        vm.assume(account != address(0x0) && account != address(_poolBalances));
        receiveAmount = bound(receiveAmount, 1, type(uint256).max - 2);
        portfolioAmount = bound(portfolioAmount, receiveAmount, type(uint256).max - 1);
        balanceAmount = bound(balanceAmount, portfolioAmount, type(uint256).max);
        _assertBalanceDeposited(_usdt, account, balanceAmount);
        _assertSentPortfolio(_usdt, account, portfolioAmount);
        _assertReceivedPortfolio(_usdt, account, receiveAmount);
    }
    function testFuzz_sendPortfolio_Sent(uint256 balanceAmount, uint256 portfolioAmount, address account) public {
        vm.assume(account != address(0x0) && account != address(_poolBalances));
        portfolioAmount = bound(portfolioAmount, 1, type(uint256).max - 1);
        balanceAmount = bound(balanceAmount, portfolioAmount, type(uint256).max);
        _assertBalanceDeposited(_usdt, account, balanceAmount);
        _assertSentPortfolio(_usdt, account, portfolioAmount);
    }
    function testFuzz_sendPortfolio_SentWhenAmountGreaterThanPoolBalance(uint256 balanceAmount, uint256 inputAmount, address account) public {
        vm.assume(account != address(0x0) && account != address(_poolBalances));
        balanceAmount = bound(balanceAmount, 1, type(uint256).max - 1);
        inputAmount = bound(inputAmount, balanceAmount, type(uint256).max);
        _assertBalanceDeposited(_usdt, address(this), balanceAmount);
        _assertSentPortfolio(_usdt, address(this), inputAmount, balanceAmount);
    }
    function _assertSetBalance(address token, uint256 amount) internal {
        vm.expectEmit(true, true, true, true, address(_poolBalances));
        emit BalanceUpdated(token, amount);
        _poolBalances.exposed_setBalance(token, amount);
        _assertBalanceEq(token, amount);
    }
    function _assertSetPortfolio(address token, uint256 amount) internal {
        vm.expectEmit(true, true, true, true, address(_poolBalances));
        emit PortfolioUpdated(token, amount);
        _poolBalances.exposed_setPortfolio(token, amount);
        _assertPortfolioEq(token, amount);
    }
    function _assertBalanceDeposited(address token, address account, uint256 amount) internal {
        deal(token, account, amount);
        uint256 oldUserBalance = IERC20(token).balanceOf(account);
        uint256 oldBalance = _poolBalances.exposed_balance(token);
        uint256 oldPoolBalance = IERC20(token).balanceOf(address(_poolBalances));
        vm.prank(account);
        IERC20(token).transfer(address(_poolBalances), amount);
        _assertSetBalance(token, oldBalance + amount);
        assertEq(IERC20(token).balanceOf(address(account)), oldUserBalance - amount, "user balance");
        assertEq(IERC20(token).balanceOf(address(_poolBalances)), oldPoolBalance + amount, "pool balance");
    }
    function _assertReceivedPortfolio(address token, address sender, uint256 amount) internal {
        uint256 oldUserBalance = IERC20(token).balanceOf(sender);
        uint256 oldBalance = _poolBalances.exposed_getBalance(token);
        uint256 oldPortfolio = _poolBalances.exposed_getPortfolio(token);
        uint256 oldPoolBalance = IERC20(token).balanceOf(address(_poolBalances));
        vm.startPrank(sender);
        IERC20(_usdt).approve(address(_poolBalances), amount);
        vm.stopPrank();
        vm.expectEmit(true, true, true, true, address(_poolBalances));
        emit PortfolioUpdated(token, oldPortfolio - amount);
        vm.expectEmit(true, true, true, true, address(_poolBalances));
        emit PortfolioReceived(token, sender, amount);
        _poolBalances.exposed_receivePortfolio(token, sender, amount);
        _assertPortfolioEq(token, oldPortfolio - amount);
        assertEq(_poolBalances.exposed_getBalance(token), oldBalance, "balance");
        assertEq(IERC20(token).balanceOf(address(sender)), oldUserBalance - amount, "user balance");
        assertEq(IERC20(token).balanceOf(address(_poolBalances)), oldPoolBalance + amount, "pool balance");
    }
    function _assertSentPortfolio(address token, address receiver, uint256 inputAmount) internal {
        _assertSentPortfolio(token, receiver, inputAmount, inputAmount);
    }
    function _assertSentPortfolio(address token, address receiver, uint256 inputAmount, uint256 actualAmount) internal {
        uint256 oldUserBalance = IERC20(token).balanceOf(receiver);
        uint256 oldBalance = _poolBalances.exposed_getBalance(token);
        uint256 oldPortfolio = _poolBalances.exposed_getPortfolio(token);
        uint256 oldPoolBalance = IERC20(token).balanceOf(address(_poolBalances));
        vm.expectEmit(true, true, true, true, address(_poolBalances));
        emit PortfolioUpdated(token, oldPortfolio + actualAmount);
        vm.expectEmit(true, true, true, true, address(_poolBalances));
        emit PortfolioSent(token, receiver, actualAmount);
        _poolBalances.exposed_sendPortfolio(token, receiver, inputAmount);
        _assertPortfolioEq(token, oldPortfolio + actualAmount);
        assertEq(_poolBalances.exposed_getBalance(token), oldBalance, "balance");
        assertEq(IERC20(token).balanceOf(address(receiver)), oldUserBalance + actualAmount, "user balance");
        assertEq(IERC20(token).balanceOf(address(_poolBalances)), oldPoolBalance - actualAmount, "pool balance");
    }
    function _assertBalanceEq(address token, uint256 balance) internal {
        assertEq(_poolBalances.exposed_balance(token), balance, "balance");
        assertEq(_poolBalances.exposed_balance(token), _poolBalances.exposed_getBalance(token), "balance eq getter");
    }
    function _assertPortfolioEq(address token, uint256 portfolio) internal {
        assertEq(_poolBalances.exposed_portfolio(token), portfolio, "portfolio");
        assertEq(_poolBalances.exposed_portfolio(token), _poolBalances.exposed_getPortfolio(token), "portfolio eq getter");
    }
}
contract PoolBalancesHarness is PoolBalances {
    function exposed_setBalance(address token, uint256 newBalance) external {
        _setBalance(token, newBalance);
    }
    function exposed_setPortfolio(address token, uint256 newPortfolio) external {
        _setPortfolio(token, newPortfolio);
    }
    function exposed_receivePortfolio(address token, address sender, uint256 amount) external {
        _receivePortfolio(token, sender, amount);
    }
    function exposed_sendPortfolio(address token, address receiver, uint256 amount) external {
        _sendPortfolio(token, receiver, amount);
    }
    function exposed_balance(address token) external view returns (uint256) {
        return _balance[token];
    }
    function exposed_portfolio(address token) external view returns (uint256) {
        return _portfolio[token];
    }
    function exposed_getBalance(address token) external view returns (uint256) {
        return _getBalance(token);
    }
    function exposed_getPortfolio(address token) external view returns (uint256) {
        return _getPortfolio(token);
    }
    function exposed_checkAmountPositive(uint256 amount) external pure {
        _checkAmountPositive(amount);
    }
}