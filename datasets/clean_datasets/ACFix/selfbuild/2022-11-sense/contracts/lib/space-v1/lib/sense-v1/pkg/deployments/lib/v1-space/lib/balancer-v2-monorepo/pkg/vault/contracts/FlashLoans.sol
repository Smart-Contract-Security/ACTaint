pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BalancerErrors.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import "./Fees.sol";
import "./interfaces/IFlashLoanRecipient.sol";
abstract contract FlashLoans is Fees, ReentrancyGuard, TemporarilyPausable {
    using SafeERC20 for IERC20;
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external override nonReentrant whenNotPaused {
        InputHelpers.ensureInputLengthMatch(tokens.length, amounts.length);
        uint256[] memory feeAmounts = new uint256[](tokens.length);
        uint256[] memory preLoanBalances = new uint256[](tokens.length);
        IERC20 previousToken = IERC20(0);
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];
            _require(token > previousToken, token == IERC20(0) ? Errors.ZERO_TOKEN : Errors.UNSORTED_TOKENS);
            previousToken = token;
            preLoanBalances[i] = token.balanceOf(address(this));
            feeAmounts[i] = _calculateFlashLoanFeeAmount(amount);
            _require(preLoanBalances[i] >= amount, Errors.INSUFFICIENT_FLASH_LOAN_BALANCE);
            token.safeTransfer(address(recipient), amount);
        }
        recipient.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 preLoanBalance = preLoanBalances[i];
            uint256 postLoanBalance = token.balanceOf(address(this));
            _require(postLoanBalance >= preLoanBalance, Errors.INVALID_POST_LOAN_BALANCE);
            uint256 receivedFeeAmount = postLoanBalance - preLoanBalance;
            _require(receivedFeeAmount >= feeAmounts[i], Errors.INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT);
            _payFeeAmount(token, receivedFeeAmount);
            emit FlashLoan(recipient, token, amounts[i], receivedFeeAmount);
        }
    }
}