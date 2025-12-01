pragma solidity ^0.5.2;
contract Admin {
    address internal _admin;
    event AdminChanged(address oldAdmin, address newAdmin);
    function getAdmin() external view returns (address) {
        return _admin;
    }
    function changeAdmin(address newAdmin) external {
        require(msg.sender == _admin, "only admin can change admin");
        emit AdminChanged(_admin, newAdmin);
        _admin = newAdmin;
    }
    modifier onlyAdmin() {
        require (msg.sender == _admin, "only admin allowed");
        _;
    }
}