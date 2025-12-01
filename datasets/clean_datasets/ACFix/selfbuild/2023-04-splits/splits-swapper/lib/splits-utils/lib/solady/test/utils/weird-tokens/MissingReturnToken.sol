pragma solidity ^0.8.4;
contract MissingReturnToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    string public constant name = "MissingReturnToken";
    string public constant symbol = "MRT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    constructor() {
        totalSupply = type(uint256).max;
        balanceOf[msg.sender] = type(uint256).max;
    }
    function approve(address spender, uint256 amount) public virtual {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
    }
    function transfer(address to, uint256 amount) public virtual {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
    }
    function transferFrom(address from, address to, uint256 amount) public virtual {
        uint256 allowed = allowance[from][msg.sender]; 
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}