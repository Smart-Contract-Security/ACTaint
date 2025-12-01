pragma solidity 0.8.9;
contract MockJOJODealerRevert {
    function deposit(uint256 primaryAmount, uint256 secondaryAmount, address to) external {
        require(false, "test For revert");
    }
}