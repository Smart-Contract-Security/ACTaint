pragma solidity 0.8.9;
import "../Impl/JUSDBankInit.t.sol";
import "../../src/Interface/IJUSDBank.sol";
import "../../src/Interface/IFlashLoanReceive.sol";
import "./MockFlashloan.sol";
contract MockFlashloan3 is IFlashLoanReceive {
    using SafeERC20 for IERC20;
    function JOJOFlashLoan(
        address asset,
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        address bob = 0x2f66c75A001Ba71ccb135934F48d844b46454543;
        address mockToken2 = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
        address jusdBank = 0x212224D2F2d262cd093eE13240ca4873fcCBbA3C;
        IERC20(asset).safeTransfer(bob, amount);
        MockFlashloan mockFlashloan = new MockFlashloan();
        IJUSDBank(jusdBank).deposit(
            address(this),
            address(mockToken2),
            5e8,
            to
        );
        IJUSDBank(jusdBank).flashLoan(
            address(mockFlashloan),
            address(mockToken2),
            20e8,
            to,
            param
        );
    }
}