pragma solidity ^0.8.4;
import "./lib/mininterfaces.sol";
import "./Factory.sol";
contract Cooler {
    error OnlyApproved();
    error Deactivated();
    error Default();
    error NoDefault();
    error NotRollable();
    Request[] public requests;
    struct Request { 
        uint256 amount; 
        uint256 interest; 
        uint256 loanToCollateral; 
        uint256 duration; 
        bool active; 
    } 
    Loan[] public loans;
    struct Loan { 
        Request request; 
        uint256 amount; 
        uint256 collateral; 
        uint256 expiry; 
        bool rollable; 
        address lender; 
    }
    mapping(uint256 => address) public approvals;
    address private immutable owner;
    ERC20 public immutable collateral;
    ERC20 public immutable debt;
    CoolerFactory public immutable factory;
    uint256 private constant decimals = 1e18;
    constructor (address o, ERC20 c, ERC20 d) {
        owner = o;
        collateral = c;
        debt = d;
        factory = CoolerFactory(msg.sender);
    }
    function request (
        uint256 amount,
        uint256 interest,
        uint256 loanToCollateral,
        uint256 duration
    ) external returns (uint256 reqID) {
        reqID = requests.length;
        factory.newEvent(reqID, CoolerFactory.Events.Request);
        requests.push(
            Request(amount, interest, loanToCollateral, duration, true)
        );
        collateral.transferFrom(msg.sender, address(this), collateralFor(amount, loanToCollateral));
    }
    function rescind (uint256 reqID) external {
        if (msg.sender != owner) 
            revert OnlyApproved();
        factory.newEvent(reqID, CoolerFactory.Events.Rescind);
        Request storage req = requests[reqID];
        if (!req.active)
            revert Deactivated();
        req.active = false;
        collateral.transfer(owner, collateralFor(req.amount, req.loanToCollateral));
    }
    function repay (uint256 loanID, uint256 repaid) external {
        Loan storage loan = loans[loanID];
        if (block.timestamp > loan.expiry) 
            revert Default();
        uint256 decollateralized = loan.collateral * repaid / loan.amount;
        if (repaid == loan.amount) delete loans[loanID];
        else {
            loan.amount -= repaid;
            loan.collateral -= decollateralized;
        }
        debt.transferFrom(msg.sender, loan.lender, repaid);
        collateral.transfer(owner, decollateralized);
    }
    function roll (uint256 loanID) external {
        Loan storage loan = loans[loanID];
        Request memory req = loan.request;
        if (block.timestamp > loan.expiry) 
            revert Default();
        if (!loan.rollable)
            revert NotRollable();
        uint256 newCollateral = collateralFor(loan.amount, req.loanToCollateral) - loan.collateral;
        uint256 newDebt = interestFor(loan.amount, req.interest, req.duration);
        loan.amount += newDebt;
        loan.expiry += req.duration;
        loan.collateral += newCollateral;
        collateral.transferFrom(msg.sender, address(this), newCollateral);
    }
    function delegate (address to) external {
        if (msg.sender != owner) 
            revert OnlyApproved();
        IDelegateERC20(address(collateral)).delegate(to);
    }
    function clear (uint256 reqID) external returns (uint256 loanID) {
        Request storage req = requests[reqID];
        factory.newEvent(reqID, CoolerFactory.Events.Clear);
        if (!req.active) 
            revert Deactivated();
        else req.active = false;
        uint256 interest = interestFor(req.amount, req.interest, req.duration);
        uint256 collat = collateralFor(req.amount, req.loanToCollateral);
        uint256 expiration = block.timestamp + req.duration;
        loanID = loans.length;
        loans.push(
            Loan(req, req.amount + interest, collat, expiration, true, msg.sender)
        );
        debt.transferFrom(msg.sender, owner, req.amount);
    }
    function toggleRoll(uint256 loanID) external returns (bool) {
        Loan storage loan = loans[loanID];
        if (msg.sender != loan.lender)
            revert OnlyApproved();
        loan.rollable = !loan.rollable;
        return loan.rollable;
    }
    function defaulted (uint256 loanID) external returns (uint256) {
        Loan memory loan = loans[loanID];
        delete loans[loanID];
        if (block.timestamp <= loan.expiry) 
            revert NoDefault();
        collateral.transfer(loan.lender, loan.collateral);
        return loan.collateral;
    }
    function approve (address to, uint256 loanID) external {
        Loan memory loan = loans[loanID];
        if (msg.sender != loan.lender)
            revert OnlyApproved();
        approvals[loanID] = to;
    }
    function transfer (uint256 loanID) external {
        if (msg.sender != approvals[loanID])
            revert OnlyApproved();
        approvals[loanID] = address(0);
        loans[loanID].lender = msg.sender;
    }
    function collateralFor(uint256 amount, uint256 loanToCollateral) public pure returns (uint256) {
        return amount * decimals / loanToCollateral;
    }
    function interestFor(uint256 amount, uint256 rate, uint256 duration) public pure returns (uint256) {
        uint256 interest = rate * duration / 365 days;
        return amount * interest / decimals;
    }
    function isDefaulted(uint256 loanID) external view returns (bool) {
        return block.timestamp > loans[loanID].expiry;
    }
    function isActive(uint256 reqID) external view returns (bool) {
        return requests[reqID].active;
    }
}