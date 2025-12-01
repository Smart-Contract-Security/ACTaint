pragma solidity ^0.8.17;
import {IERC20} from "../../../interface/tokens/IERC20.sol";
import {IntegrationBaseTest} from "../utils/IntegrationBaseTest.sol";
import {UniV2Controller} from "controller/uniswap/UniV2Controller.sol";
import {IUniV2Factory} from "controller/uniswap/IUniV2Factory.sol";
contract UniV2SwapIntegrationTest is IntegrationBaseTest {
    address account;
    address user = cheats.addr(1);
    address constant UNIV2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address[] wethToUsdt = [WETH, USDT];
    address[] usdtToWeth = [USDT, WETH];
    UniV2Controller uniV2Controller;
    function setupUniV2Controller() private {
        uniV2Controller = new UniV2Controller(WETH, IUniV2Factory(FACTORY));
        controller.updateController(UNIV2_ROUTER, uniV2Controller);
    }
    function setUp() public {
        setupContracts();
        setupOracles();
        setupUniV2Controller();
        setupWethController();
        setupCurveController();
        account = openAccount(user);
    }
    function testSwapExactTokensForTokens(uint64 amt) public {
        cheats.assume(amt > 1 ether);
        deposit(user, account, address(0), amt);
        wrapEth(account, amt, user);
        bytes memory data = abi.encodeWithSignature(
            "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
            amt, 0, wethToUsdt, account, 1893456000);
        cheats.startPrank(user);
        accountManager.approve(account, WETH, UNIV2_ROUTER, type(uint).max);
        accountManager.exec(account, UNIV2_ROUTER, 0, data);
        cheats.stopPrank();
        assertEq(IERC20(WETH).balanceOf(account), 0);
        assertGe(IERC20(USDT).balanceOf(account), 0);
    }
    function testSwapTokensForExactTokens(uint64 amt) public {
        uint amountOut = 1000 * 1e6; 
        cheats.assume(amt > 1 ether);
        deposit(user, account, address(0), amt);
        wrapEth(account, amt, user);
        bytes memory data = abi.encodeWithSignature(
            "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)",
            amountOut, amt, wethToUsdt, account, 1893456000);
        cheats.startPrank(user);
        accountManager.approve(account, WETH, UNIV2_ROUTER, type(uint).max);
        accountManager.exec(account, UNIV2_ROUTER, 0, data);
        cheats.stopPrank();
        assertGe(IERC20(WETH).balanceOf(account), 0);
        assertEq(IERC20(USDT).balanceOf(account), amountOut);
    }
    function testSwapExactEthForTokens(uint64 amt) public {
        cheats.assume(amt > 1 ether);
        deposit(user, account, address(0), amt);
        bytes memory data = abi.encodeWithSignature(
            "swapExactETHForTokens(uint256,address[],address,uint256)",
            0, wethToUsdt, account, 1893456000);
        cheats.startPrank(user);
        accountManager.approve(account, WETH, UNIV2_ROUTER, type(uint).max);
        accountManager.exec(account, UNIV2_ROUTER, amt, data);
        cheats.stopPrank();
        assertEq(account.balance, 0);
        assertGt(IERC20(USDT).balanceOf(account), 0);
    }
    function testSwapEthForExactTokens(uint64 amt) public {
        uint amountOut = 1000 * 1e6; 
        cheats.assume(amt > 1 ether);
        deposit(user, account, address(0), amt);
        bytes memory data = abi.encodeWithSignature(
            "swapETHForExactTokens(uint256,address[],address,uint256)",
            amountOut, wethToUsdt, account, 1893456000);
        cheats.startPrank(user);
        accountManager.approve(account, WETH, UNIV2_ROUTER, type(uint).max);
        accountManager.exec(account, UNIV2_ROUTER, amt, data);
        cheats.stopPrank();
        assertGe(account.balance, 0);
        assertEq(IERC20(USDT).balanceOf(account), amountOut);
    }
    function testSwapExactTokensForEth(uint64 amt) public {
        cheats.assume(amt > 1 ether);
        deposit(user, account, address(0), amt);
        swapEthUsdt(amt, account, user);
        uint amtUsdt = IERC20(USDT).balanceOf(account);
        bytes memory data = abi.encodeWithSignature(
            "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
            amtUsdt, 0, usdtToWeth, account, 1893456000);
        cheats.startPrank(user);
        accountManager.approve(account, USDT, UNIV2_ROUTER, type(uint).max);
        accountManager.exec(account, UNIV2_ROUTER, 0, data);
        cheats.stopPrank();
        assertGt(account.balance, 0);
        assertEq(IERC20(USDT).balanceOf(account), 0);
    }
    function testSwapTokensForExactEth(uint64 amt) public {
        uint amountOut = 1 ether;
        cheats.assume(amt > 15e9 gwei); 
        deposit(user, account, address(0), amt);
        swapEthUsdt(amt, account, user);
        uint amtUsdt = IERC20(USDT).balanceOf(account);
        bytes memory data = abi.encodeWithSignature(
            "swapTokensForExactETH(uint256,uint256,address[],address,uint256)",
            amountOut, amtUsdt, usdtToWeth, account, 1893456000);
        cheats.startPrank(user);
        accountManager.approve(account, USDT, UNIV2_ROUTER, type(uint).max);
        accountManager.exec(account, UNIV2_ROUTER, 0, data);
        cheats.stopPrank();
        assertGe(account.balance, amountOut);
    }
}