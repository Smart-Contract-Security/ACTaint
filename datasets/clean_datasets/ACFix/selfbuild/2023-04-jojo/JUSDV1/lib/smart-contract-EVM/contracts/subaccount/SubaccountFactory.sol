import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Subaccount.sol";
pragma solidity 0.8.9;
contract SubaccountFactory {
    address immutable template;
    mapping(address => address[]) subaccountRegistry;
    event NewSubaccount(
        address indexed master,
        uint256 subaccountIndex,
        address subaccountAddress
    );
    constructor() {
        template = address(new Subaccount());
        Subaccount(template).init(address(this));
    }
    function newSubaccount() external returns (address subaccount) {
        subaccount = Clones.clone(template);
        Subaccount(subaccount).init(msg.sender);
        subaccountRegistry[msg.sender].push(subaccount);
        emit NewSubaccount(
            msg.sender,
            subaccountRegistry[msg.sender].length - 1,
            subaccount
        );
    }
    function getSubaccounts(address master)
        external
        view
        returns (address[] memory)
    {
        return subaccountRegistry[master];
    }
    function getSubaccount(address master, uint256 index)
        external
        view
        returns (address)
    {
        return subaccountRegistry[master][index];
    }
}