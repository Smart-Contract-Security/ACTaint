pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
import "../mocks/MockJOJODealerRevert.sol";
import "../mocks/MockChainLink15000.sol";
contract JUSDBankBorrowTest is JUSDBankInitTest {
    function testSelfWithdraw() public {
        mockToken1.transfer(alice, 10e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        for(uint i=0; i<100; i++) {
            jusdBank.withdraw(address(mockToken1), 10e18, alice, true);
        }
        address[] memory list= jusdBank.getUserCollateralList(alice);
        uint256 maxBorrow = jusdBank.getDepositMaxMintAmount(alice);
        console.log("maxBorrow:", maxBorrow);
        console.log(list.length);
        assertEq(list.length, 1);
        cheats.expectRevert("AFTER_BORROW_ACCOUNT_IS_NOT_SAFE");
        jusdBank.borrow(100000e6, alice, false);
    }
}