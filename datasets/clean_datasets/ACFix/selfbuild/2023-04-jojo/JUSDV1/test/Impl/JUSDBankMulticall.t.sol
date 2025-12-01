pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
contract JUSDBankMulticallTest is JUSDBankInitTest {
    function testHelperDeposit() public {
        bytes memory a = jusdBank.getDepositData(
            alice,
            address(mockToken2),
            10e18,
            alice
        );
        emit log_bytes(a);
    }
    function testHelperBorrow() public {
        bytes memory a = jusdBank.getBorrowData(10e18, address(0x123), false);
        emit log_bytes(a);
    }
    function testHelperRepay() public {
        bytes memory a = jusdBank.getRepayData(10e18, alice);
        emit log_bytes(a);
    }
    function testHelperWithdraw() public {
        bytes memory a = jusdBank.getWithdrawData(
            address(mockToken2),
            10e18,
            alice,
            false
        );
        emit log_bytes(a);
    }
    function testHelperMultical() public {
        bytes[] memory data = new bytes[](2);
        data[0] = jusdBank.getDepositData(
            alice,
            address(mockToken1),
            10e18,
            alice
        );
        data[1] = jusdBank.getBorrowData(3000e18, alice, false);
        bytes memory a = jusdBank.getMulticallData(data);
        emit log_bytes(a);
    }
    function testMulticall() public {
        mockToken1.transfer(alice, 10e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        bytes[] memory data = new bytes[](2);
        data[0] = jusdBank.getDepositData(
            alice,
            address(mockToken1),
            10e18,
            alice
        );
        data[1] = jusdBank.getBorrowData(3000e6, alice, false);
        jusdBank.multiCall(data);
        assertEq(jusdBank.getDepositBalance(address(mockToken1), alice), 10e18);
        assertEq(jusdBank.getBorrowBalance(alice), 3000e6);
        data[1] = "0";
        cheats.expectRevert("ERC20: insufficient allowance");
        jusdBank.multiCall(data);
    }
    function testSetOperator() public {
        bytes memory data = jusdBank.getSetOperator(
            address(0x55483C180181b68c3F4213E8f4C774FB0D393148),
            true
        );
        emit log_bytes(data);
    }
}