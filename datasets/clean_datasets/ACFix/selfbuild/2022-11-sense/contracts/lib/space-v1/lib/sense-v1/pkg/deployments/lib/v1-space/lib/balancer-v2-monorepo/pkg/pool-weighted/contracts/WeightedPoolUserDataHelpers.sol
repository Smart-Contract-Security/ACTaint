pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "./BaseWeightedPool.sol";
library WeightedPoolUserDataHelpers {
    function joinKind(bytes memory self) internal pure returns (BaseWeightedPool.JoinKind) {
        return abi.decode(self, (BaseWeightedPool.JoinKind));
    }
    function exitKind(bytes memory self) internal pure returns (BaseWeightedPool.ExitKind) {
        return abi.decode(self, (BaseWeightedPool.ExitKind));
    }
    function initialAmountsIn(bytes memory self) internal pure returns (uint256[] memory amountsIn) {
        (, amountsIn) = abi.decode(self, (BaseWeightedPool.JoinKind, uint256[]));
    }
    function exactTokensInForBptOut(bytes memory self)
        internal
        pure
        returns (uint256[] memory amountsIn, uint256 minBPTAmountOut)
    {
        (, amountsIn, minBPTAmountOut) = abi.decode(self, (BaseWeightedPool.JoinKind, uint256[], uint256));
    }
    function tokenInForExactBptOut(bytes memory self) internal pure returns (uint256 bptAmountOut, uint256 tokenIndex) {
        (, bptAmountOut, tokenIndex) = abi.decode(self, (BaseWeightedPool.JoinKind, uint256, uint256));
    }
    function allTokensInForExactBptOut(bytes memory self) internal pure returns (uint256 bptAmountOut) {
        (, bptAmountOut) = abi.decode(self, (BaseWeightedPool.JoinKind, uint256));
    }
    function exactBptInForTokenOut(bytes memory self) internal pure returns (uint256 bptAmountIn, uint256 tokenIndex) {
        (, bptAmountIn, tokenIndex) = abi.decode(self, (BaseWeightedPool.ExitKind, uint256, uint256));
    }
    function exactBptInForTokensOut(bytes memory self) internal pure returns (uint256 bptAmountIn) {
        (, bptAmountIn) = abi.decode(self, (BaseWeightedPool.ExitKind, uint256));
    }
    function bptInForExactTokensOut(bytes memory self)
        internal
        pure
        returns (uint256[] memory amountsOut, uint256 maxBPTAmountIn)
    {
        (, amountsOut, maxBPTAmountIn) = abi.decode(self, (BaseWeightedPool.ExitKind, uint256[], uint256));
    }
}