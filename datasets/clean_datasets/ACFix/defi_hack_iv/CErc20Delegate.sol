pragma solidity ^0.5.16;
import "./CToken.sol";
interface CompLike {
  function delegate(address delegatee) external;
}
contract CErc20 is CToken, CErc20Interface {
    function initialize(address underlying_,
                        ComptrollerInterface comptroller_,
                        InterestRateModel interestRateModel_,
                        uint initialExchangeRateMantissa_,
                        string memory name_,
                        string memory symbol_,
                        uint8 decimals_) public {
        super.initialize(comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);
        underlying = underlying_;
        EIP20Interface(underlying).totalSupply();
    }
    function mint(uint mintAmount) external returns (uint) {
        (uint err,) = mintInternal(mintAmount);
        return err;
    }
    function redeem(uint redeemTokens) external returns (uint) {
        return redeemInternal(redeemTokens);
    }
    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        return redeemUnderlyingInternal(redeemAmount);
    }
    function borrow(uint borrowAmount) external returns (uint) {
        return borrowInternal(borrowAmount);
    }
    function repayBorrow(uint repayAmount) external returns (uint) {
        (uint err,) = repayBorrowInternal(repayAmount);
        return err;
    }
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint) {
        (uint err,) = repayBorrowBehalfInternal(borrower, repayAmount);
        return err;
    }
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint) {
        (uint err,) = liquidateBorrowInternal(borrower, repayAmount, cTokenCollateral);
        return err;
    }
    function sweepToken(EIP20NonStandardInterface token) external {
    	require(address(token) != underlying, "CErc20::sweepToken: can not sweep underlying token");
    	uint256 balance = token.balanceOf(address(this));
    	token.transfer(admin, balance);
    }
    function _addReserves(uint addAmount) external returns (uint) {
        return _addReservesInternal(addAmount);
    }
    function getCashPrior() internal view returns (uint) {
        EIP20Interface token = EIP20Interface(underlying);
        return token.balanceOf(address(this));
    }
    function doTransferIn(address from, uint amount) internal returns (uint) {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying);
        uint balanceBefore = EIP20Interface(underlying).balanceOf(address(this));
        token.transferFrom(from, address(this), amount);
        bool success;
        assembly {
            switch returndatasize()
                case 0 {                       
                    success := not(0)          
                }
                case 32 {                      
                    returndatacopy(0, 0, 32)
                    success := mload(0)        
                }
                default {                      
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");
        uint balanceAfter = EIP20Interface(underlying).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;   
    }
    function doTransferOut(address payable to, uint amount) internal {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying);
        token.transfer(to, amount);
        bool success;
        assembly {
            switch returndatasize()
                case 0 {                      
                    success := not(0)          
                }
                case 32 {                     
                    returndatacopy(0, 0, 32)
                    success := mload(0)        
                }
                default {                     
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }
    function _delegateCompLikeTo(address compLikeDelegatee) external {
        require(msg.sender == admin, "only the admin may set the comp-like delegate");
        CompLike(underlying).delegate(compLikeDelegatee);
    }
}