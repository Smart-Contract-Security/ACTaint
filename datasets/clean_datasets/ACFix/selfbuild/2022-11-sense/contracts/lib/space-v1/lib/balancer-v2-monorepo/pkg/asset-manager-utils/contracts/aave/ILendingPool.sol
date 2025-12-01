pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import { ILendingPoolAddressesProvider } from "./ILendingPoolAddressesProvider.sol";
import { DataTypes } from "./DataTypes.sol";
interface ILendingPool {
    event Deposit(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint16 indexed referral
    );
    event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);
    event Borrow(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint256 borrowRateMode,
        uint256 borrowRate,
        uint16 indexed referral
    );
    event Repay(address indexed reserve, address indexed user, address indexed repayer, uint256 amount);
    event Swap(address indexed reserve, address indexed user, uint256 rateMode);
    event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);
    event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);
    event RebalanceStableBorrowRate(address indexed reserve, address indexed user);
    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint256 premium,
        uint16 referralCode
    );
    event Paused();
    event Unpaused();
    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receiveAToken
    );
    event ReserveDataUpdated(
        address indexed reserve,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);
    function swapBorrowRateMode(address asset, uint256 rateMode) external;
    function rebalanceStableBorrowRate(address asset, address user) external;
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
    function initReserve(
        address reserve,
        address aTokenAddress,
        address stableDebtAddress,
        address variableDebtAddress,
        address interestRateStrategyAddress
    ) external;
    function setReserveInterestRateStrategyAddress(address reserve, address rateStrategyAddress) external;
    function setConfiguration(address reserve, uint256 configuration) external;
    function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory);
    function getUserConfiguration(address user) external view returns (DataTypes.UserConfigurationMap memory);
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
    function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
    function finalizeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 balanceFromAfter,
        uint256 balanceToBefore
    ) external;
    function getReservesList() external view returns (address[] memory);
    function getAddressesProvider() external view returns (ILendingPoolAddressesProvider);
    function setPause(bool val) external;
    function paused() external view returns (bool);
}