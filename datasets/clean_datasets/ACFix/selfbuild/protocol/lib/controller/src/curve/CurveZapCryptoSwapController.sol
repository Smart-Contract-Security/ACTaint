pragma solidity ^0.8.17;
import {IController} from "../core/IController.sol";
import {IStableSwapPool} from "./IStableSwapPool.sol";
import {IControllerFacade} from "../core/IControllerFacade.sol";
contract CurveZapCryptoSwapController is IController {
    bytes4 public constant ADD_LIQUIDITY = 0x4515cef3;
    bytes4 public constant REMOVE_LIQUIDITY = 0xecb586a5;
    bytes4 public constant REMOVE_LIQUIDITY_ONE_COIN = 0xf1dc3cc9;
    function canCall(address target, bool useEth, bytes calldata data)
        external
        view
        returns (bool, address[] memory, address[] memory)
    {
        bytes4 sig = bytes4(data);
        if (sig == ADD_LIQUIDITY) return canAddLiquidity(target, useEth, data);
        if (sig == REMOVE_LIQUIDITY_ONE_COIN)
            return canRemoveLiquidityOneCoin(target, data);
        if (sig == REMOVE_LIQUIDITY) return canRemoveLiquidity(target);
        return (false, new address[](0), new address[](0));
    }
    function canAddLiquidity(address target, bool useEth, bytes calldata data)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        if (!useEth) return (false, new address[](0), new address[](0));
        address[] memory tokensIn = new address[](1);
        tokensIn[0] = IStableSwapPool(target).token();
        uint i; uint j;
        (uint[3] memory amounts) = abi.decode(data[4:], (uint[3]));
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
        (,uint256 i, uint256 min_amount) = abi.decode(
            data[4:],
            (uint256, uint256, uint256)
        );
        if (min_amount == 0)
            return (false, new address[](0), new address[](0));
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = IStableSwapPool(target).token();
        if (i == 2) return (true, new address[](0), tokensOut);
        address[] memory tokensIn = new address[](1);
        tokensIn[0] = IStableSwapPool(target).coins(i);
        return (true, tokensIn, tokensOut);
    }
    function canRemoveLiquidity(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = IStableSwapPool(target).token();
        address[] memory tokensIn = new address[](3);
        tokensIn[0] = IStableSwapPool(target).coins(0);
        tokensIn[1] = IStableSwapPool(target).coins(1);
        tokensIn[2] = IStableSwapPool(target).coins(2);
        return (true, tokensIn, tokensOut);
    }
}