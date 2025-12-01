pragma solidity ^0.8.0;
contract MockUniswapOracle {
    function quoteAllAvailablePoolsWithTimePeriod(
        uint128 baseAmount,
        address baseToken,
        address quoteToken,
        uint32 period
    ) external view returns (uint256 quoteAmount, address[] memory queriedPools){
        address[] memory a = new address[](1);
        return (949999, a);
    }
}