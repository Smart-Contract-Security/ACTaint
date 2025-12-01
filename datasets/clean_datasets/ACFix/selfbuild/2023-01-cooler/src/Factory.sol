pragma solidity ^0.8.0;
import "./Cooler.sol";
import "./lib/ERC20.sol";
contract CoolerFactory {
    event Request(address cooler, address collateral, address debt, uint256 reqID);
    event Rescind(address cooler, uint256 reqID);
    event Clear(address cooler, uint256 reqID);
    mapping(address => bool) public created;
    mapping(address => mapping(ERC20 => mapping(ERC20 => address))) private coolerFor;
    mapping(ERC20 => mapping(ERC20 => address[])) public coolersFor;
    function generate (ERC20 collateral, ERC20 debt) external returns (address cooler) {
        cooler = coolerFor[msg.sender][collateral][debt];
        if (cooler == address(0)) {
            cooler = address(new Cooler(msg.sender, collateral, debt));
            coolerFor[msg.sender][collateral][debt] = cooler;
            coolersFor[collateral][debt].push(cooler);
            created[cooler] = true;
        }
    }
    enum Events {Request, Rescind, Clear}
    function newEvent (uint256 id, Events ev) external {
        require (created[msg.sender], "Only Created");
        if (ev == Events.Clear) emit Clear(msg.sender, id);
        else if (ev == Events.Rescind) emit Rescind(msg.sender, id);  
        else if (ev == Events.Request)
            emit Request(
                msg.sender, 
                address(Cooler(msg.sender).collateral()), 
                address(Cooler(msg.sender).debt()), 
                id
            );
    }
}