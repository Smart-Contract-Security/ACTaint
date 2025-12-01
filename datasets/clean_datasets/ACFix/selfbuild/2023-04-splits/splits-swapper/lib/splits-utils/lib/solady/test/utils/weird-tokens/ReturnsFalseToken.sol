pragma solidity ^0.8.4;
contract ReturnsFalseToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    string public constant name = "ReturnsFalseToken";
    string public constant symbol = "RFT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    constructor() {
        totalSupply = type(uint256).max;
        balanceOf[msg.sender] = type(uint256).max;
    }
    function approve(address, uint256) public virtual returns (bool) {
        return false;
    }
    function transfer(address, uint256) public virtual returns (bool) {
        return false;
    }
    function transferFrom(address, address, uint256) public virtual returns (bool) {
        return false;
    }
}