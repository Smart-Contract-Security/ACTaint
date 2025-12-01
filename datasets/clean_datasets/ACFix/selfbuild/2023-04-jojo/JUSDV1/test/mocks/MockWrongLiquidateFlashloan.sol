pragma solidity 0.8.9;
import "../../src/Interface/IJUSDBank.sol";
import "../../src/Interface/IJUSDExchange.sol";
import "../../src/Interface/IFlashLoanReceive.sol";
import {DecimalMath} from "../../src/lib/DecimalMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPriceChainLink} from "../../src/Interface/IPriceChainLink.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract LiquidateCollateralRepayNotEnough is IFlashLoanReceive {
    using SafeERC20 for IERC20;
    using DecimalMath for uint256;
    address public jusdBank;
    address public jusdExchange;
    address public immutable USDC;
    address public immutable JUSD;
    address public insurance;
    struct LiquidateData {
        uint256 actualCollateral;
        uint256 insuranceFee;
        uint256 actualLiquidatedT0;
        uint256 actualLiquidated;
        uint256 liquidatedRemainUSDC;
    }
    constructor(
        address _jusdBank,
        address _jusdExchange,
        address _USDC,
        address _JUSD,
        address _insurance
    ) {
        jusdBank = _jusdBank;
        jusdExchange = _jusdExchange;
        USDC = _USDC;
        JUSD = _JUSD;
        insurance = _insurance;
    }
    function JOJOFlashLoan(
        address asset,
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        (LiquidateData memory liquidateData, bytes memory originParam) = abi
            .decode(param, (LiquidateData, bytes));
        (address approveTarget, address swapTarget, , bytes memory data) = abi
            .decode(originParam, (address, address, address, bytes));
        IERC20(asset).approve(approveTarget, amount);
        (bool success, ) = swapTarget.call(data);
        if (success == false) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        IERC20(USDC).approve(jusdExchange, liquidateData.actualLiquidated - 1);
        IJUSDExchange(jusdExchange).buyJUSD(
            liquidateData.actualLiquidated - 1,
            address(this)
        );
        IERC20(JUSD).approve(jusdBank, liquidateData.actualLiquidated - 1);
        IJUSDBank(jusdBank).repay(liquidateData.actualLiquidated - 1, to);
    }
}
contract LiquidateCollateralInsuranceNotEnough is IFlashLoanReceive {
    using SafeERC20 for IERC20;
    using DecimalMath for uint256;
    address public jusdBank;
    address public jusdExchange;
    address public immutable USDC;
    address public immutable JUSD;
    address public insurance;
    struct LiquidateData {
        uint256 actualCollateral;
        uint256 insuranceFee;
        uint256 actualLiquidatedT0;
        uint256 actualLiquidated;
        uint256 liquidatedRemainUSDC;
    }
    constructor(
        address _jusdBank,
        address _jusdExchange,
        address _USDC,
        address _JUSD,
        address _insurance
    ) {
        jusdBank = _jusdBank;
        jusdExchange = _jusdExchange;
        USDC = _USDC;
        JUSD = _JUSD;
        insurance = _insurance;
    }
    function JOJOFlashLoan(
        address asset,
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        (LiquidateData memory liquidateData, bytes memory originParam) = abi
            .decode(param, (LiquidateData, bytes));
        (address approveTarget, address swapTarget, , bytes memory data) = abi
            .decode(originParam, (address, address, address, bytes));
        IERC20(asset).approve(approveTarget, amount);
        (bool success, ) = swapTarget.call(data);
        if (success == false) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        IERC20(USDC).approve(jusdExchange, liquidateData.actualLiquidated);
        IJUSDExchange(jusdExchange).buyJUSD(
            liquidateData.actualLiquidated,
            address(this)
        );
        IERC20(JUSD).approve(jusdBank, liquidateData.actualLiquidated);
        IJUSDBank(jusdBank).repay(liquidateData.actualLiquidated, to);
        IERC20(USDC).transfer(insurance, liquidateData.insuranceFee - 1);
        if (liquidateData.liquidatedRemainUSDC != 0) {
            IERC20(USDC).transfer(to, liquidateData.liquidatedRemainUSDC - 1);
        }
    }
}
contract LiquidateCollateralLiquidatedNotEnough is IFlashLoanReceive {
    using SafeERC20 for IERC20;
    using DecimalMath for uint256;
    address public jusdBank;
    address public jusdExchange;
    address public immutable USDC;
    address public immutable JUSD;
    address public insurance;
    struct LiquidateData {
        uint256 actualCollateral;
        uint256 insuranceFee;
        uint256 actualLiquidatedT0;
        uint256 actualLiquidated;
        uint256 liquidatedRemainUSDC;
    }
    constructor(
        address _jusdBank,
        address _jusdExchange,
        address _USDC,
        address _JUSD,
        address _insurance
    ) {
        jusdBank = _jusdBank;
        jusdExchange = _jusdExchange;
        USDC = _USDC;
        JUSD = _JUSD;
        insurance = _insurance;
    }
    function JOJOFlashLoan(
        address asset,
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        (LiquidateData memory liquidateData, bytes memory originParam) = abi
            .decode(param, (LiquidateData, bytes));
        (address approveTarget, address swapTarget, , bytes memory data) = abi
            .decode(originParam, (address, address, address, bytes));
        IERC20(asset).approve(approveTarget, amount);
        (bool success, ) = swapTarget.call(data);
        if (success == false) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        IERC20(USDC).approve(jusdExchange, liquidateData.actualLiquidated);
        IJUSDExchange(jusdExchange).buyJUSD(
            liquidateData.actualLiquidated,
            address(this)
        );
        IERC20(JUSD).approve(jusdBank, liquidateData.actualLiquidated);
        IJUSDBank(jusdBank).repay(liquidateData.actualLiquidated, to);
        IERC20(USDC).transfer(insurance, liquidateData.insuranceFee);
        if (liquidateData.liquidatedRemainUSDC != 0) {
            IERC20(USDC).transfer(to, liquidateData.liquidatedRemainUSDC - 1);
        }
    }
}