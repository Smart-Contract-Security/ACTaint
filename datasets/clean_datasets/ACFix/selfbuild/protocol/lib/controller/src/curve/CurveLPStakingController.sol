pragma solidity ^0.8.15;
import {IController} from "../core/IController.sol";
interface IChildGauge {
    function lp_token() external view returns (address);
    function reward_count() external view returns (uint256);
    function reward_tokens(uint256) external view returns (address);
}
contract CurveLPStakingController is IController {
    bytes4 constant DEPOSIT = 0xb6b55f25;
    bytes4 constant DEPOSITCLAIM = 0x83df6747;
    bytes4 constant WITHDRAW = 0x2e1a7d4d;
    bytes4 constant WITHDRAWCLAIM = 0x00ebf5dd;
    bytes4 constant CLAIM = 0xe6f1daf2;
    function canCall(address target, bool, bytes calldata data)
        external
        view
        returns (bool, address[] memory, address[] memory)
    {
        bytes4 sig = bytes4(data);
        if (sig == DEPOSIT) canDeposit(target);
        if (sig == DEPOSITCLAIM) canDepositAndClaim(target);
        if (sig == WITHDRAW) canWithdraw(target);
        if (sig == WITHDRAWCLAIM) canWithdrawAndClaim(target);
        if (sig == CLAIM) canClaim(target);
        return (false, new address[](0), new address[](0));
    }
    function canDeposit(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        address[] memory tokensIn = new address[](1);
        address[] memory tokensOut = new address[](1);
        tokensIn[0] = target;
        tokensOut[0] = IChildGauge(target).lp_token();
        return (true, tokensIn, tokensOut);
    }
    function canDepositAndClaim(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        uint count = IChildGauge(target).reward_count();
        address[] memory tokensIn = new address[](count + 1);
        for (uint i; i<count; i++)
            tokensIn[i] = IChildGauge(target).reward_tokens(i);
        tokensIn[count] = target;
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = IChildGauge(target).lp_token();
        return (true, tokensIn, tokensOut);
    }
    function canWithdraw(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        address[] memory tokensIn = new address[](1);
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = target;
        tokensIn[0] = IChildGauge(target).lp_token();
        return (true, tokensIn, tokensOut);
    }
    function canWithdrawAndClaim(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        uint count = IChildGauge(target).reward_count();
        address[] memory tokensIn = new address[](count + 1);
        for (uint i; i<count; i++)
            tokensIn[i] = IChildGauge(target).reward_tokens(i);
        tokensIn[count] = IChildGauge(target).lp_token();
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = target;
        return (true, tokensIn, tokensOut);
    }
    function canClaim(address target)
        internal
        view
        returns (bool, address[] memory, address[] memory)
    {
        uint count = IChildGauge(target).reward_count();
        address[] memory tokensIn = new address[](count);
        for (uint i; i<count; i++)
            tokensIn[i] = IChildGauge(target).reward_tokens(i);
        return (true, tokensIn, new address[](0));
    }
}