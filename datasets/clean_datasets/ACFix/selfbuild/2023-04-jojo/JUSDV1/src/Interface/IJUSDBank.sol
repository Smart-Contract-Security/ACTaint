pragma solidity 0.8.9;
import {DataTypes} from "../lib/DataTypes.sol";
interface IJUSDBank {
    function deposit(
        address from,
        address collateral,
        uint256 amount,
        address to
    ) external;
    function borrow(uint256 amount, address to, bool isDepositToJOJO) external;
    function withdraw(
        address collateral,
        uint256 amount,
        address to,
        bool isInternal
    ) external;
    function repay(uint256 amount, address to) external returns (uint256);
    function liquidate(
        address liquidatedTrader,
        address liquidationCollateral,
        address liquidator,
        uint256 liquidationAmount,
        bytes memory param,
        uint256 expectPrice
    ) external returns (DataTypes.LiquidateData memory liquidateData);
    function handleDebt(address[] calldata liquidatedTraders) external;
    function flashLoan(
        address receiver,
        address collateral,
        uint256 amount,
        address to,
        bytes memory param
    ) external;
    function getReservesList() external view returns (address[] memory);
    function getDepositMaxMintAmount(
        address user
    ) external view returns (uint256);
    function getCollateralMaxMintAmount(
        address collateral,
        uint256 amoount
    ) external view returns (uint256 maxAmount);
    function getMaxWithdrawAmount(
        address collateral,
        address user
    ) external view returns (uint256 maxAmount);
    function isAccountSafe(address user) external view returns (bool);
    function getCollateralPrice(
        address collateral
    ) external view returns (uint256);
    function getIfHasCollateral(
        address from,
        address collateral
    ) external view returns (bool);
    function getDepositBalance(
        address collateral,
        address from
    ) external view returns (uint256);
    function getBorrowBalance(address from) external view returns (uint256);
    function getUserCollateralList(
        address from
    ) external view returns (address[] memory);
}