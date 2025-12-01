pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/Authentication.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import "./interfaces/IProtocolFeesCollector.sol";
contract ProtocolFeesCollector is IProtocolFeesCollector, Authentication, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 private constant _MAX_PROTOCOL_SWAP_FEE_PERCENTAGE = 50e16; 
    uint256 private constant _MAX_PROTOCOL_FLASH_LOAN_FEE_PERCENTAGE = 1e16; 
    IVault public immutable override vault;
    uint256 private _swapFeePercentage;
    uint256 private _flashLoanFeePercentage;
    constructor(IVault _vault)
        Authentication(bytes32(uint256(address(this))))
    {
        vault = _vault;
    }
    function withdrawCollectedFees(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        address recipient
    ) external override nonReentrant authenticate {
        InputHelpers.ensureInputLengthMatch(tokens.length, amounts.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];
            token.safeTransfer(recipient, amount);
        }
    }
    function setSwapFeePercentage(uint256 newSwapFeePercentage) external override authenticate {
        _require(newSwapFeePercentage <= _MAX_PROTOCOL_SWAP_FEE_PERCENTAGE, Errors.SWAP_FEE_PERCENTAGE_TOO_HIGH);
        _swapFeePercentage = newSwapFeePercentage;
        emit SwapFeePercentageChanged(newSwapFeePercentage);
    }
    function setFlashLoanFeePercentage(uint256 newFlashLoanFeePercentage) external override authenticate {
        _require(
            newFlashLoanFeePercentage <= _MAX_PROTOCOL_FLASH_LOAN_FEE_PERCENTAGE,
            Errors.FLASH_LOAN_FEE_PERCENTAGE_TOO_HIGH
        );
        _flashLoanFeePercentage = newFlashLoanFeePercentage;
        emit FlashLoanFeePercentageChanged(newFlashLoanFeePercentage);
    }
    function getSwapFeePercentage() external view override returns (uint256) {
        return _swapFeePercentage;
    }
    function getFlashLoanFeePercentage() external view override returns (uint256) {
        return _flashLoanFeePercentage;
    }
    function getCollectedFeeAmounts(IERC20[] memory tokens)
        external
        view
        override
        returns (uint256[] memory feeAmounts)
    {
        feeAmounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            feeAmounts[i] = tokens[i].balanceOf(address(this));
        }
    }
    function getAuthorizer() external view override returns (IAuthorizer) {
        return _getAuthorizer();
    }
    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }
    function _getAuthorizer() internal view returns (IAuthorizer) {
        return vault.getAuthorizer();
    }
}