pragma solidity ^0.5.16;
import "./CointrollerInterface.sol";
import "./InterestRateModel.sol";
import "./EIP20NonStandardInterface.sol";
contract RTokenStorage {
    bool internal _notEntered;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint internal constant borrowRateMaxMantissa = 0.0005e16;
    uint internal constant reserveFactorMaxMantissa = 1e18;
    address payable public admin;
    address payable public pendingAdmin;
    CointrollerInterface public cointroller;
    InterestRateModel public interestRateModel;
    uint internal initialExchangeRateMantissa;
    uint public reserveFactorMantissa;
    uint public accrualBlockNumber;
    uint public borrowIndex;
    uint public totalBorrows;
    uint public totalReserves;
    uint public totalSupply;
    mapping (address => uint) internal accountTokens;
    mapping (address => mapping (address => uint)) internal transferAllowances;
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }
    mapping(address => BorrowSnapshot) internal accountBorrows;
}
contract RTokenInterface is RTokenStorage {
    bool public constant isRToken = true;
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);
    event Mint(address minter, uint mintAmount, uint mintTokens);
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address rTokenCollateral, uint seizeTokens);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewAdmin(address oldAdmin, address newAdmin);
    event NewCointroller(CointrollerInterface oldCointroller, CointrollerInterface newCointroller);
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);
    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);
    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);
    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
    event Failure(uint error, uint info, uint detail);
    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) public view returns (uint);
    function exchangeRateCurrent() public returns (uint);
    function exchangeRateStored() public view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() public returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint);
    function _acceptAdmin() external returns (uint);
    function _setCointroller(CointrollerInterface newCointroller) public returns (uint);
    function _setReserveFactor(uint newReserveFactorMantissa) external returns (uint);
    function _reduceReserves(uint reduceAmount) external returns (uint);
    function _setInterestRateModel(InterestRateModel newInterestRateModel) public returns (uint);
}
contract RBep20Storage {
    address public underlying;
}
contract RBep20Interface is RBep20Storage {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, RTokenInterface rTokenCollateral) external returns (uint);
    function sweepToken(EIP20NonStandardInterface token) external;
    function _addReserves(uint addAmount) external returns (uint);
}
contract RDelegationStorage {
    address public implementation;
}
contract RDelegatorInterface is RDelegationStorage {
    event NewImplementation(address oldImplementation, address newImplementation);
    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) public;
}
contract RDelegateInterface is RDelegationStorage {
    function _becomeImplementation(bytes memory data) public;
    function _resignImplementation() public;
}