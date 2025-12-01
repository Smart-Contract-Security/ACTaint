pragma solidity ^0.4.24;
contract Fiocoin {
    string public constant symbol = "FIOCOIN";
    string public constant name = "Fiocoin";
    uint8 public constant decimals = 0;
    uint256 _totalSupply = 514; 
    address public owner;
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    mapping (address => bool) public frozenAccount;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event FrozenFunds(address target, bool frozen);
    modifier onlyOwner() {
        if (msg.sender != owner) {
            throw;
        }
        _;
    }
    function owned() {
        owner = msg.sender;
    }
    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
    function Fiocoin() {
        owner = msg.sender;
        balances[owner] = _totalSupply;
    }
    function totalSupply() constant returns (uint256 totalSupply) {
        return _totalSupply;
    }
    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }
    function transfer(address _to, uint256 _amount) returns (bool success) {
        if (frozenAccount[msg.sender]) throw;
        if (balances[msg.sender] >= _amount
            && _amount > 0
            && balances[_to] + _amount > balances[_to]) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(msg.sender, _to, _amount);
            return true;
        } else {
            return false;
        }
    }
    function transferFrom(address _from, address _to, uint256 _amount) returns (bool success) {
        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0
            && balances[_to] + _amount > balances[_to]) {
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }
    function approve(address _spender, uint256 _amount) returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balances[target] += mintedAmount;
        _totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
}
