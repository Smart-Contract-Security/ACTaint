pragma solidity ^0.8.17;
import {IController} from "../core/IController.sol";
import {IStableSwapPool} from "./IStableSwapPool.sol";
contract StableSwap2PoolController is IController {
    bytes4 public constant EXCHANGE = 0x3df02124;
    bytes4 public constant ADD_LIQUIDITY = 0x0b4c7e4d;
    bytes4 public constant REMOVE_LIQUIDITY = 0x5b36389c;
    bytes4 public constant REMOVE_LIQUIDITY_ONE_COIN = 0x1a4d01d2;
    function canCall(address target, bool, bytes calldata data)
        external
        view
        returns (bool, address[] memory, address[] memory)
    {
        bytes4 sig = bytes4(data);
        if (sig == ADD_LIQUIDITY) return canAddLiquidity(target, data);
        if (sig == REMOVE_LIQUIDITY_ONE_COIN)
            return canRemoveLiquidityOneCoin(target, data);
        if (sig == REMOVE_LIQUIDITY) return canRemoveLiquidity(target);
        if (sig == EXCHANGE) return canExchange(target, data);
        return (false, new address[](0), new address[](0));
    }
    function canAddLiquidity(address target, bytes calldata data)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        address[] memory tokensIn = new address[](1);
        tokensIn[0] = target;
        uint i; uint j;
        (uint[2] memory amounts) = abi.decode(data[4:], (uint[2]));
        address[] memory tokensOut = new address[](2);
        while(i < 2) {
            if(amounts[i] > 0)
                tokensOut[j++] = IStableSwapPool(target).coins(i);
            unchecked { ++i; }
        }
        assembly { mstore(tokensOut, j) }
        return (true, tokensIn, tokensOut);
    }
    function canRemoveLiquidityOneCoin(address target, bytes calldata data)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        (,int128 i, uint256 min_amount) = abi.decode(
            data[4:],
            (uint256, int128, uint256)
        );
        if (min_amount == 0)
            return (false, new address[](0), new address[](0));
        address[] memory tokensIn = new address[](1);
        address[] memory tokensOut = new address[](1);
        tokensIn[0] = IStableSwapPool(target).coins(uint128(i));
        tokensOut[0] = target;
        return (true, tokensIn, tokensOut);
    }
    function canRemoveLiquidity(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = target;
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = IStableSwapPool(target).coins(0);
        tokensIn[1] = IStableSwapPool(target).coins(1);
        return (true, tokensIn, tokensOut);
    }
    function canExchange(address target, bytes calldata data)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        (int128 i, int128 j,,) = abi.decode(
            data[4:],
            (int128, int128, uint256, uint256)
        );
        address[] memory tokensIn = new address[](1);
        address[] memory tokensOut = new address[](1);
        tokensIn[0] = IStableSwapPool(target).coins(uint128(j));
        tokensOut[0] = IStableSwapPool(target).coins(uint128(i));
        return (
            true,
            tokensIn,
            tokensOut
        );
    }
}