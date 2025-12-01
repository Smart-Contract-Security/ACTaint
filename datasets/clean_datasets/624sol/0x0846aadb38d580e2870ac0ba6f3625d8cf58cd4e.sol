pragma solidity ^0.4.24;
contract owned {
    address public owner;
    constructor() public {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
contract stoppable{
    struct ShareHolder {
        address addr;
        bool agree;
    }
    ShareHolder[] public shareHolders4;
    function _sh_init(address[] shareHolderAddresses4) internal {
        require(shareHolderAddresses4.length==4,"only support 4 shareholders.");
        for (uint i = 0; i < shareHolderAddresses4.length; i++) {
            shareHolders4.push(ShareHolder({
                addr: shareHolderAddresses4[i],
                agree: false
            }));
        }
    }
    function _sh_index(address target) internal view returns (uint) {
        for(uint i=0;i<shareHolders4.length;i++){
            if(target == shareHolders4[i].addr){
                return i;
            }
        }
        return shareHolders4.length;
    }
    function _sh_clear_agree() internal {
        for(uint i=0;i<shareHolders4.length;i++){
            shareHolders4[i].agree = false;
        }
    }
    function sh_doAgree() public {
        uint i = _sh_index(msg.sender);
        require(i<shareHolders4.length, "not valid shareholder.");
        shareHolders4[i].agree = true;
    }
    function sh_doTransfer(address other) public {
        uint i1 = _sh_index(msg.sender);
        require(i1<shareHolders4.length,"self is not valid shareholder.");
        uint i2 = _sh_index(other);
        require(i2==shareHolders4.length,"other is alreay shareholder.");
        shareHolders4[i1].addr = other;
        shareHolders4[i1].agree = false;
    }
    modifier sh_agreed {
        uint sum = 0;
        for(uint i=0;i<shareHolders4.length;i++){
            if(shareHolders4[i].agree){
                sum += 1;
            }
        }
        require(sum >= 3, "need at least 3 shareholders to agree.");
        _;
    }
    bool public isRunning = true;
    function start() public sh_agreed returns (bool currentStatus) {
        require(!isRunning, "contract is running already.");
        isRunning = true;
        _sh_clear_agree();
        return isRunning;
    }
    function stop() public sh_agreed returns (bool currentStatus) {
        require(isRunning, "contract is not running already.");
        isRunning = false;
        _sh_clear_agree();
        return isRunning;
    }
    modifier ifRunning {
        require(isRunning, "contract is not running.");
        _;
    }
}
interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }
contract TokenERC20 is stoppable{
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Burn(address indexed from, uint256 value);
    constructor(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  
        balanceOf[msg.sender] = totalSupply;                
        name = tokenName;                                   
        symbol = tokenSymbol;                               
    }
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != 0x0);
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }
    function transfer(address _to, uint256 _value) public ifRunning returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }
    function transferFrom(address _from, address _to, uint256 _value) public ifRunning returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }
    function approve(address _spender, uint256 _value) public ifRunning
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public ifRunning
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }
    function burn(uint256 _value) public ifRunning returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   
        balanceOf[msg.sender] -= _value;            
        totalSupply -= _value;                      
        emit Burn(msg.sender, _value);
        return true;
    }
    function burnFrom(address _from, uint256 _value) public ifRunning returns (bool success) {
        require(balanceOf[_from] >= _value);                
        require(_value <= allowance[_from][msg.sender]);    
        balanceOf[_from] -= _value;                         
        allowance[_from][msg.sender] -= _value;             
        totalSupply -= _value;                              
        emit Burn(_from, _value);
        return true;
    }
}
contract MyAdvancedToken is owned, TokenERC20 {
    uint256 public sellPrice;
    uint256 public buyPrice;
    mapping (address => bool) public frozenAccount;
    event FrozenFunds(address target, bool frozen);
    constructor(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol,
        address[] shareHolderAddresses4
    ) TokenERC20(initialSupply, tokenName, tokenSymbol) public {
        _sh_init(shareHolderAddresses4);
    }
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                               
        require (balanceOf[_from] >= _value);               
        require (balanceOf[_to] + _value >= balanceOf[_to]); 
        require(!frozenAccount[_from]);                     
        require(!frozenAccount[_to]);                       
        balanceOf[_from] -= _value;                         
        balanceOf[_to] += _value;                           
        emit Transfer(_from, _to, _value);
    }
    function mintToken(address target, uint256 mintedAmount) public onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        emit Transfer(0, this, mintedAmount);
        emit Transfer(this, target, mintedAmount);
    }
    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) public onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    function buy() payable public ifRunning {
        uint amount = msg.value / buyPrice;               
        _transfer(this, msg.sender, amount);              
    }
    function sell(uint256 amount) public ifRunning {
        address myAddress = this;
        require(myAddress.balance >= amount * sellPrice);      
        _transfer(msg.sender, this, amount);              
        msg.sender.transfer(amount * sellPrice);          
    }
}