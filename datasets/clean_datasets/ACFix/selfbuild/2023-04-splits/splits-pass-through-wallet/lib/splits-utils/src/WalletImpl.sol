pragma solidity ^0.8.17;
import {OwnableImpl} from "./OwnableImpl.sol";
abstract contract WalletImpl is OwnableImpl {
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }
    event ExecCalls(Call[] calls);
    constructor() {}
    function __initWallet(address owner_) internal {
        OwnableImpl.__initOwnable(owner_);
    }
    function execCalls(Call[] calldata calls_)
        external
        payable
        onlyOwner
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        blockNumber = block.number;
        uint256 length = calls_.length;
        returnData = new bytes[](length);
        bool success;
        for (uint256 i; i < length;) {
            Call calldata calli = calls_[i];
            (success, returnData[i]) = calli.to.call{value: calli.value}(calli.data);
            require(success, string(returnData[i]));
            unchecked {
                ++i;
            }
        }
        emit ExecCalls(calls_);
    }
}