pragma solidity 0.8.9;
import "../Impl/JUSDBankInit.t.sol";
import "../../src/Interface/IJUSDBank.sol";
import "../../src/Interface/IFlashLoanReceive.sol";
contract MockFlashloan2 is IFlashLoanReceive {
    using SafeERC20 for IERC20;
    function JOJOFlashLoan(
        address asset,
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        IERC20(asset).safeTransfer(to, amount);
    }
}