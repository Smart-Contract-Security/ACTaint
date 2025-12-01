pragma solidity ^0.8.0;
import "./Escrow.sol";
abstract contract ConditionalEscrow is Escrow {
    function withdrawalAllowed(address payee) public view virtual returns (bool);
    function withdraw(address payable payee) public virtual override {
        require(withdrawalAllowed(payee), "ConditionalEscrow: payee is not allowed to withdraw");
        super.withdraw(payee);
    }
}