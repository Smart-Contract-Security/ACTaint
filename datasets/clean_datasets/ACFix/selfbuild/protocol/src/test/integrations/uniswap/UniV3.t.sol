pragma solidity ^0.8.17;
import {IERC20} from "../../../interface/tokens/IERC20.sol";
import {IAccount} from "../../../interface/core/IAccount.sol";
import {IntegrationBaseTest} from "../utils/IntegrationBaseTest.sol";
import {ISwapRouterV3} from "controller/uniswap/ISwapRouterV3.sol";
import {UniV3Controller} from "controller/uniswap/UniV3Controller.sol";
contract UniV3IntegrationTest is IntegrationBaseTest {
    address account;
    address user = cheats.addr(1);
    address uniV3Router = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address quoter = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    UniV3Controller uniV3Controller;
    function setupUniV3Controller() private {
        uniV3Controller = new UniV3Controller(controller);
        controller.updateController(uniV3Router, uniV3Controller);
    }
    function setUp() public {
        setupContracts();
        setupOracles();
        setupUniV3Controller();
        setupCurveController();
        setupWethController();
        account = openAccount(user);
    }
    function testMultiCallExactOutputSingleEthUSDT(uint64 amt) public {
        uint256 amtOut = 100 * 1e6; 
        cheats.assume(amt > 1e8 gwei);
        deposit(user, account, address(0), amt);
        bytes[] memory multiData = new bytes[](2);
        multiData[0] = abi.encodeWithSignature(
            "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint160))",
            getExactOutputParams(
                WETH,
                USDT,
                account,
                amtOut,
                amt
            )
        );
        multiData[1] = abi.encodeWithSignature("refundETH()");
        bytes memory data = abi.encodeWithSignature(
            "multicall(bytes[])",
            multiData
        );
        cheats.prank(user);
        accountManager.exec(account, uniV3Router, amt, data);
        assertEq(IERC20(USDT).balanceOf(account), amtOut);
        assertEq(IAccount(account).assets(0), USDT);
        assertTrue(account.balance > 0);
    }
    function testMultiCallExactOutputSingleUSDTETH(uint64 amt) public {
        uint256 amtOut = 1e6 gwei;
        cheats.assume(amt > 1e8 gwei);
        deposit(user, account, address(0), amt);
        swapEthUsdt(amt, account, user);
        uint usdtAmount = IERC20(USDT).balanceOf(account);
        bytes[] memory multiData = new bytes[](2);
        multiData[0] = abi.encodeWithSignature(
            "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint160))",
            getExactOutputParams(
                USDT,
                WETH,
                uniV3Router,
                amtOut,
                usdtAmount
            )
        );
        multiData[1] = abi.encodeWithSignature(
            "unwrapWETH9(uint256,address)",
            amtOut, account
        );
        bytes memory data = abi.encodeWithSignature(
            "multicall(bytes[])",
            multiData
        );
        cheats.startPrank(user);
        accountManager.approve(account, USDT, uniV3Router, type(uint).max);
        accountManager.exec(account, uniV3Router, 0, data);
        assertLe(IERC20(USDT).balanceOf(account), usdtAmount);
        assertTrue(account.balance > 0);
    }
    function testMultiCallExactInputSingleUSDTETH(uint64 amt) public {
        testMultiCallExactOutputSingleEthUSDT(amt);
        uint usdtAmount = IERC20(USDT).balanceOf(account);
        bytes[] memory multiData = new bytes[](2);
        multiData[0] = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
            getExactInputParams(
                USDT,
                WETH,
                uniV3Router,
                0,
                usdtAmount
            )
        );
        multiData[1] = abi.encodeWithSignature(
            "unwrapWETH9(uint256,address)",
            1e6 gwei, account
        );
        bytes memory data = abi.encodeWithSignature(
            "multicall(bytes[])",
            multiData
        );
        cheats.startPrank(user);
        accountManager.approve(account, USDT, uniV3Router, type(uint).max);
        accountManager.exec(account, uniV3Router, 0, data);
        assertGe(IERC20(USDT).balanceOf(account), 0);
        assertLe(account.balance, amt);
        assertEq(IAccount(account).getAssets().length, 0);
    }
    function testExactOutputSingleWETHUSDT(uint64 amt) public {
        uint256 amtOut = 100 * 1e6; 
        cheats.assume(amt > 1e8 gwei);
        deposit(user, account, address(0), amt);
        wrapEth(account, amt, user);
        bytes memory data = abi.encodeWithSignature(
            "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint160))",
            getExactOutputParams(
                WETH,
                USDT,
                account,
                amtOut,
                amt
            )
        );
        cheats.startPrank(user);
        accountManager.approve(account, WETH, uniV3Router, type(uint).max);
        accountManager.exec(account, uniV3Router, 0, data);
        assertLe(IERC20(USDT).balanceOf(account), amtOut);
        assertTrue(IERC20(WETH).balanceOf(account) > 0);
        assertEq(IAccount(account).getAssets().length, 2);
    }
    function testExactInputSingleETHUSDT(uint64 amt) public {
        cheats.assume(amt > 1e8 gwei);
        deposit(user, account, address(0), amt);
        bytes memory data = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
            getExactInputParams(
                WETH,
                USDT,
                account,
                0,
                amt
            )
        );
        cheats.prank(user);
        accountManager.exec(account, uniV3Router, amt, data);
        assertTrue(IERC20(USDT).balanceOf(account) > 0);
        assertEq(account.balance, 0);
        assertEq(IAccount(account).assets(0), USDT);
    }
    function testExactInputSingleWETHUSDT(uint64 amt) public {
        cheats.assume(amt > 1e8 gwei);
        deposit(user, account, address(0), amt);
        wrapEth(account, amt, user);
        bytes memory data = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
            getExactInputParams(
                WETH,
                USDT,
                account,
                0,
                amt
            )
        );
        cheats.startPrank(user);
        accountManager.approve(account, WETH, uniV3Router, type(uint).max);
        accountManager.exec(account, uniV3Router, 0, data);
        assertTrue(IERC20(USDT).balanceOf(account) > 0);
        assertEq(account.balance, 0);
        assertEq(IAccount(account).assets(0), USDT);
    }
    function getExactOutputParams(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountOut,
        uint256 amountIn
    )
        private
        pure
        returns (ISwapRouterV3.ExactOutputSingleParams memory data)
    {
        data = ISwapRouterV3.ExactOutputSingleParams(
            tokenIn,
            tokenOut,
            3000,
            recipient,
            amountOut,
            amountIn,
            0
        );
    }
    function getExactInputParams(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountOut,
        uint256 amountIn
    )
        private
        pure
        returns (ISwapRouterV3.ExactInputSingleParams memory data)
    {
        data = ISwapRouterV3.ExactInputSingleParams(
            tokenIn,
            tokenOut,
            3000,
            recipient,
            amountIn,
            amountOut,
            0
        );
    }
}