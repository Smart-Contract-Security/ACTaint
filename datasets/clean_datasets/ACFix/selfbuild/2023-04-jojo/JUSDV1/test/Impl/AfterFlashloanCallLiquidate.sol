pragma solidity 0.8.9;
import "./JUSDBankInit.t.sol";
import "../mocks/MockToken.sol";
import "../../src/Impl/flashloanImpl/FlashLoanLiquidate.sol";
import "../mocks/MockChainLink900.sol";
    struct LiquidateData {
        uint256 actualCollateral;
        uint256 insuranceFee;
        uint256 actualLiquidatedT0;
        uint256 actualLiquidated;
        uint256 liquidatedRemainUSDC;
    }
contract JUSDExploitTest is JUSDBankInitTest{
    function testAfterFlashloanLiquidate() public{
        Repay flashloanRepay = new Repay(
            address(mockToken1),
            address(jusdBank),
            address(jusdExchange),
            insurance
        );
        Attack attack = new Attack(
            address(mockToken1),
            address(jusdBank),
            address(jusdExchange),
            insurance,
            address(flashloanRepay)
        );
        mockToken1.transfer(alice, 10e18);
        mockToken1.transfer(address(flashloanRepay), 10e18);
        vm.startPrank(alice);
        mockToken1.approve(address(jusdBank), 10e18);
        jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
        uint256 maxBorrow = jusdBank.getDepositMaxMintAmount(alice);
        jusdBank.borrow(maxBorrow * 90 / 100, alice, false);
        uint256 jusdBalance = jusd.balanceOf(alice);
        console.log("Alice jusd balance : %d", jusdBalance);
        bytes memory param = abi.encode(
            address(jusdBank), 
            address(jusdExchange),
            address(mockToken1),
            address(jusd),
            insurance,
            address(flashloanRepay)
            );
        cheats.expectRevert("ReentrancyGuard: Withdraw or Borrow or Liquidate flashLoan reentrant call");
        jusdBank.flashLoan(address(attack), address(mockToken1), 10e18-1, alice, param);
        vm.stopPrank();
        console.log("HackEnd");
        uint256 flashloanRepayJusdBalance = jusd.balanceOf(address(flashloanRepay));
        uint256 flashloanRepayMockToken1Balance = mockToken1.balanceOf(address(flashloanRepay));
        console.log("Alice jusd balance : %d", jusd.balanceOf(alice));
        console.log("Alice mockToken1 balance : %d", mockToken1.balanceOf(alice));
        console.log("flashloanRepay jusd balance : %d", flashloanRepayJusdBalance);
        console.log("flashloanRepay mockToken1 balance : %d", flashloanRepayMockToken1Balance);
    }
}
contract Attack{
    address public mockToken1;
    address public jusdBank;
    address public jusdExchange;
    address public jusd;
    address public insurance;
    address public flashloanRepay;
    constructor(
        address _mockToken1,
        address _jusdBank,
        address _jusdExchange,
        address _insurance,
        address _flashloanRepay
    ){
        mockToken1 = _mockToken1;
        jusdBank = _jusdBank;
        jusdExchange = _jusdExchange;
        insurance = _insurance;
        flashloanRepay = _flashloanRepay;
    }
    function JOJOFlashLoan(
        address asset, 
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        bytes memory afterParam = abi.encode(flashloanRepay, param);
        JUSDBank(jusdBank).liquidate(
            to,
            address(mockToken1),
            address(this),
            1,
            afterParam,
            0
        );
        IERC20(asset).transfer(to, IERC20(asset).balanceOf(address(this)));
    }
}
contract Repay{
    address public mockToken1;
    address public jusdBank;
    address public jusdExchange;
    address public insurance;
    constructor(
        address _mockToken1,
        address _jusdBank,
        address _jusdExchange,
        address _insurance
    ){
        mockToken1 = _mockToken1;
        jusdBank = _jusdBank;
        jusdExchange = _jusdExchange;
        insurance = _insurance;
    }
    function JOJOFlashLoan(
        address asset, 
        uint256 amount,
        address to,
        bytes calldata param
    ) external {
        (LiquidateData memory liquidateData, bytes memory originParam) = abi.decode(param, (LiquidateData, bytes));
        uint256 assetAmount = IERC20(asset).balanceOf(address(this));
        IERC20(asset).approve(jusdBank, 10e18);
        IERC20(asset).transfer(insurance, liquidateData.insuranceFee);
        if (liquidateData.liquidatedRemainUSDC != 0) {
            IERC20(asset).transfer(to, liquidateData.liquidatedRemainUSDC);
        }
        IERC20(asset).transfer(
            to,
            assetAmount - liquidateData.insuranceFee - liquidateData.actualLiquidated
                - liquidateData.liquidatedRemainUSDC
        );
    }
}