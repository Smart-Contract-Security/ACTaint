pragma solidity ^0.8.0;
import "../Factory.sol";
import "../lib/mininterfaces.sol";
contract ClearingHouse {
    error OnlyApproved();
    error OnlyFromFactory();
    error BadEscrow();
    error InterestMinimum();
    error LTCMaximum();
    error DurationMaximum();
    address public operator;
    address public overseer;
    address public pendingOperator;
    address public pendingOverseer;
    ERC20 public immutable dai;
    ERC20 public immutable gOHM;
    address public immutable treasury;
    CoolerFactory public immutable factory;
    uint256 public constant minimumInterest = 2e16; 
    uint256 public constant maxLTC = 2_500 * 1e18; 
    uint256 public constant maxDuration = 365 days; 
    constructor (
        address oper, 
        address over, 
        ERC20 g, 
        ERC20 d, 
        CoolerFactory f, 
        address t
    ) {
        operator = oper;
        overseer = over;
        gOHM = g;
        dai = d;
        factory = f;
        treasury = t;
    }
    function clear (Cooler cooler, uint256 id) external returns (uint256) {
        if (msg.sender != operator) 
            revert OnlyApproved();
        if (!factory.created(address(cooler))) 
            revert OnlyFromFactory();
        if (cooler.collateral() != gOHM || cooler.debt() != dai)
            revert BadEscrow();
        (
            uint256 amount, 
            uint256 interest, 
            uint256 ltc, 
            uint256 duration,
        ) = cooler.requests(id);
        if (interest < minimumInterest) 
            revert InterestMinimum();
        if (ltc > maxLTC) 
            revert LTCMaximum();
        if (duration > maxDuration) 
            revert DurationMaximum();
        dai.approve(address(cooler), amount);
        return cooler.clear(id);
    }
    function toggleRoll(Cooler cooler, uint256 loanID) external {
        if (msg.sender != operator) 
            revert OnlyApproved();
        cooler.toggleRoll(loanID);
    }
    function fund (uint256 amount) external {
        if (msg.sender != overseer) 
            revert OnlyApproved();
        ITreasury(treasury).manage(address(dai), amount);
    }
    function defund (ERC20 token, uint256 amount) external {
        if (msg.sender != operator && msg.sender != overseer) 
            revert OnlyApproved();
        token.transfer(treasury, amount);
    }
    function push (address newAddress) external {
        if (msg.sender == overseer) 
            pendingOverseer = newAddress;
        else if (msg.sender == operator) 
            pendingOperator = newAddress;
        else revert OnlyApproved();
    }
    function pull () external {
        if (msg.sender == pendingOverseer) {
            overseer = pendingOverseer;
            pendingOverseer = address(0);
        } else if (msg.sender == pendingOperator) {
            operator = pendingOperator;
            pendingOperator = address(0);
        } else revert OnlyApproved();
    }
}