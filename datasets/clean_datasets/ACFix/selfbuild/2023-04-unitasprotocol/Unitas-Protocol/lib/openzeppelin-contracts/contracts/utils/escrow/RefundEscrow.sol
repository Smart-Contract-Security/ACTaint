pragma solidity ^0.8.0;
import "./ConditionalEscrow.sol";
contract RefundEscrow is ConditionalEscrow {
    using Address for address payable;
    enum State {
        Active,
        Refunding,
        Closed
    }
    event RefundsClosed();
    event RefundsEnabled();
    State private _state;
    address payable private immutable _beneficiary;
    constructor(address payable beneficiary_) {
        require(beneficiary_ != address(0), "RefundEscrow: beneficiary is the zero address");
        _beneficiary = beneficiary_;
        _state = State.Active;
    }
    function state() public view virtual returns (State) {
        return _state;
    }
    function beneficiary() public view virtual returns (address payable) {
        return _beneficiary;
    }
    function deposit(address refundee) public payable virtual override {
        require(state() == State.Active, "RefundEscrow: can only deposit while active");
        super.deposit(refundee);
    }
    function close() public virtual onlyOwner {
        require(state() == State.Active, "RefundEscrow: can only close while active");
        _state = State.Closed;
        emit RefundsClosed();
    }
    function enableRefunds() public virtual onlyOwner {
        require(state() == State.Active, "RefundEscrow: can only enable refunds while active");
        _state = State.Refunding;
        emit RefundsEnabled();
    }
    function beneficiaryWithdraw() public virtual {
        require(state() == State.Closed, "RefundEscrow: beneficiary can only withdraw while closed");
        beneficiary().sendValue(address(this).balance);
    }
    function withdrawalAllowed(address) public view override returns (bool) {
        return state() == State.Refunding;
    }
}