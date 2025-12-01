pragma solidity ^0.8.0;
import "./TestFactory.sol";
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
        address t,
        uint256[] memory b
    ) {
        operator = oper;
        overseer = over;
        gOHM = g;
        dai = d;
        factory = f;
        treasury = t;
        budget = b;
    }
    function clear (Cooler cooler, uint256 id, uint256 time) external returns (uint256) {
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
        return cooler.clear(id, time);
    }
    function toggleRoll(Cooler cooler, uint256 loanID) external {
        if (msg.sender != operator) 
            revert OnlyApproved();
        cooler.toggleRoll(loanID);
    }
    uint256[] public budget;
    uint256 public lastFunded;
    uint256 public constant cadence = 7 days;
    function fund (uint256 time) external {
        if (lastFunded + cadence < time) {
            for (uint256 i; i < budget.length; i++) {
                if (budget[i] != 0) {
                    lastFunded = lastFunded == 0 ? time : lastFunded + cadence;
                    ITreasury(treasury).manage(address(dai), budget[i]);
                    delete budget[i];
                    break;
                }
            }
        }
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