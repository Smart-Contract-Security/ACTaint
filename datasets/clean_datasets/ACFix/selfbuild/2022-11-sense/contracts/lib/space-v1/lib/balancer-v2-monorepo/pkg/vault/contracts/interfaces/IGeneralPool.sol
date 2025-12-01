pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "./IBasePool.sol";
interface IGeneralPool is IBasePool {
    function onSwap(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) external returns (uint256 amount);
}