pragma solidity ^0.8.17;
import {Errors} from "../../../utils/Errors.sol";
import {IERC20} from "../../../interface/tokens/IERC20.sol";
import {IAccount} from "../../../interface/core/IAccount.sol";
import {IntegrationBaseTest} from "../utils/IntegrationBaseTest.sol";
interface IStableSwapPool {
    function get_dy(uint256, uint256, uint256) external view returns (uint256);
}
contract CurveIntegrationTest is IntegrationBaseTest {
    address account;
    address user = cheats.addr(1);
    function setUp() public {
        setupContracts();
        setupOracles();
        setupWethController();
        setupCurveController();
        account = openAccount(user);
    }
    function testSwapWethUsdt(uint64 amt) public {
        cheats.assume(amt > 1e8 gwei); 
        deposit(user, account, address(0), amt);
        cheats.prank(user);
        accountManager.exec(
            account,
            WETH,
            amt,
            abi.encodeWithSignature("deposit()")
        );
        uint256 minValue = IStableSwapPool(tricryptoPool).get_dy(
            uint256(2), 
            uint256(0), 
            amt
        );
        bytes memory data = abi.encodeWithSignature(
            "exchange(uint256,uint256,uint256,uint256,bool)",
            uint256(2), 
            uint256(0), 
            amt,
            minValue,
            false
        );
        cheats.startPrank(user);
        accountManager.approve(account, WETH, tricryptoPool, amt);
        accountManager.exec(account, tricryptoPool, 0, data);
        assertGe(IERC20(USDT).balanceOf(account), minValue);
        assertEq(IERC20(WETH).balanceOf(account), 0);
        assertEq(IAccount(account).assets(0), USDT);
    }
    function testSwapEthUsdt(uint64 amt) public {
        cheats.assume(amt > 1e8 gwei); 
        deposit(user, account, address(0), amt);
        uint256 minValue = IStableSwapPool(tricryptoPool).get_dy(
            uint256(2), 
            uint256(0), 
            amt
        );
        swapEthUsdt(amt, account, user);
        assertEq(account.balance, 0);
        assertEq(IAccount(account).assets(0), USDT);
        assertGe(IERC20(USDT).balanceOf(account), minValue);
    }
    function testDepositEth(uint64 amt) public {
        cheats.assume(amt > 1e8 gwei); 
        deposit(user, account, address(0), amt);
        depositCurveLiquidity(account, amt, user);
        assertTrue(IERC20(crv3crypto).balanceOf(account) > 0);
        assertEq(IAccount(account).assets(0), crv3crypto);
    }
    function testWithdrawEth(uint64 amt) public {
        testDepositEth(amt);
        bytes memory data = abi.encodeWithSignature(
            "remove_liquidity(uint256,uint256[3])",
            IERC20(crv3crypto).balanceOf(account),
            [0, 0, 1]
        );
        cheats.startPrank(user);
        accountManager.approve(account, crv3crypto, tricryptoPool, amt);
        accountManager.exec(account, tricryptoPool, 0, data);
        assertTrue(IERC20(WETH).balanceOf(account) > 0);
        assertEq(IAccount(account).assets(0), WETH);
    }
    function testWithdrawOnlyEth(uint64 amt) public {
        testDepositEth(amt);
        bytes memory data = abi.encodeWithSignature(
            "remove_liquidity_one_coin(uint256,uint256,uint256)",
            IERC20(crv3crypto).balanceOf(account),
            2,
            1
        );
        cheats.startPrank(user);
        accountManager.approve(account, crv3crypto, tricryptoPool, amt);
        accountManager.exec(account, tricryptoPool, 0, data);
        assertTrue(IERC20(WETH).balanceOf(account) > 0);
        assertEq(IAccount(account).assets(0), WETH);
    }
    function testSwapSigError(uint64 amt, bytes4 sig) public {
        bytes memory data = abi.encodeWithSelector(sig);
        cheats.prank(user);
        cheats.expectRevert(Errors.FunctionCallRestricted.selector);
        accountManager.exec(account, tricryptoPool, amt, data);
    }
}