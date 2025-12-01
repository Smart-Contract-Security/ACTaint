pragma solidity 0.8.9;
library DataTypes {
    struct ReserveInfo {
        uint256 initialMortgageRate;
        uint256 maxTotalDepositAmount;
        uint256 maxDepositAmountPerAccount;
        uint256 maxColBorrowPerAccount;
        address oracle;
        uint256 totalDepositAmount;
        uint256 liquidationMortgageRate;
        uint256 liquidationPriceOff;
        uint256 insuranceFeeRate;
        bool isFinalLiquidation;
        bool isDepositAllowed;
        bool isBorrowAllowed;
    }
    struct UserInfo {
        mapping(address => uint256) depositBalance;
        mapping(address => bool) hasCollateral;
        uint256 t0BorrowBalance;
        address[] collateralList;
    }
    struct LiquidateData {
        uint256 actualCollateral;
        uint256 insuranceFee;
        uint256 actualLiquidatedT0;
        uint256 actualLiquidated;
        uint256 liquidatedRemainUSDC;
    }
}