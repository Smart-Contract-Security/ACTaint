pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
interface IFlashLoanRecipient {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}