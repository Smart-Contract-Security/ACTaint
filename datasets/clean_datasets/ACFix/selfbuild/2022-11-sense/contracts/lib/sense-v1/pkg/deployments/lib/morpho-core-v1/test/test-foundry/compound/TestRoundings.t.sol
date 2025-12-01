pragma solidity 0.8.13;
import "./setup/TestSetup.sol";
contract TestRounding is TestSetup {
    function testRoundingError1() public {
        uint256 amountSupplied = 1e18;
        supplier1.approve(dai, amountSupplied);
        supplier1.supply(cDai, amountSupplied);
        uint256 balanceOnCompInUnderlying = ICToken(cDai).balanceOfUnderlying(address(morpho));
        assertFalse(balanceOnCompInUnderlying == amountSupplied, "comparison in underlying units");
    }
    function testRoundingError2() public {
        uint256 amountSupplied = 1e5;
        supplier1.approve(dai, amountSupplied);
        supplier1.supply(cDai, amountSupplied);
        uint256 balanceOnCompInUnderlying = ICToken(cDai).balanceOfUnderlying(address(morpho));
        assertFalse(balanceOnCompInUnderlying == amountSupplied, "comparison in underlying units");
    }
    function testRoundingError3() public {
        deal(dai, address(this), 1e20);
        ERC20(dai).approve(cDai, type(uint64).max);
        ICToken(cDai).mint(1);
        ICToken(cDai).mint(1e18);
        ICToken(cDai).borrow(1);
        ICToken(cDai).repayBorrow(1);
        hevm.expectRevert("redeemTokens zero");
        ICToken(cDai).redeemUnderlying(1);
    }
}