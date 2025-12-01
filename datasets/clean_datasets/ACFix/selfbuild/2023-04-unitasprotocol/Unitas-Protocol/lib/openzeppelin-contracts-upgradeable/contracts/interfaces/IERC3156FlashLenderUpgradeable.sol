pragma solidity ^0.8.0;
import "./IERC3156FlashBorrowerUpgradeable.sol";
interface IERC3156FlashLenderUpgradeable {
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function flashLoan(
        IERC3156FlashBorrowerUpgradeable receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}