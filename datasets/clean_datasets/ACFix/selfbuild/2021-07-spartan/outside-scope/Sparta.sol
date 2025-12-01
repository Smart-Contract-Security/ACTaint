pragma solidity 0.8.3;
import "./iBEP20.sol";
import "./iDAO.sol";
import "./iBASEv1.sol"; 
import "./iUTILS.sol";
import "./iBEP677.sol"; 
contract Sparta is iBEP20 {
    string public constant override name = 'Spartan Protocol Token V2';
    string public constant override symbol = 'SPARTA';
    uint8 public constant override decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    bool public emitting;
    bool public minting;
    bool private savedSpartans;
    uint256 public feeOnTransfer;
    uint256 public emissionCurve;
    uint256 private _100m;
    uint256 public maxSupply;
    uint256 public secondsPerEra;
    uint256 public nextEraTime;
    address public DAO;
    address public DEPLOYER;
    address public BASEv1;
    event NewEra(uint256 nextEraTime, uint256 emission);
    modifier onlyDAO() {
        require(msg.sender == DAO || msg.sender == DEPLOYER, "!DAO");
        _;
    }
    constructor(address _baseV1) {
        _100m = 100 * 10**6 * 10**decimals; 
        maxSupply = 300 * 10**6 * 10**decimals; 
        emissionCurve = 2048;
        BASEv1 = _baseV1;
        secondsPerEra =  800; 
        nextEraTime = block.timestamp + secondsPerEra;
        DEPLOYER = msg.sender;
        _balances[msg.sender] = 1 * 10**6 * 10**decimals;
        totalSupply = 1 * 10**6 * 10**decimals;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender]+(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "allowance err");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }
     function _approve( address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "sender");
        require(spender != address(0), "spender");
        if (_allowances[owner][spender] < type(uint256).max) { 
            _allowances[owner][spender] = amount;
            emit Approval(owner, spender, amount);
        }
    }
     function transferFrom(address sender, address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] < type(uint256).max) {
            uint256 currentAllowance = _allowances[sender][msg.sender];
            require(currentAllowance >= amount, "allowance err");
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        return true;
    }
    function approveAndCall(address recipient, uint amount, bytes calldata data) external returns (bool) {
      _approve(msg.sender, recipient, type(uint256).max); 
      iBEP677(recipient).onTokenApproval(address(this), amount, msg.sender, data); 
      return true;
     }
    function transferAndCall(address recipient, uint amount, bytes calldata data) external returns (bool) {
      _transfer(msg.sender, recipient, amount);
      iBEP677(recipient).onTokenTransfer(address(this), amount, msg.sender, data); 
      return true;
     }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "transfer err");
        require(recipient != address(this), "recipient"); 
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "balance err");
        uint _fee = iUTILS(UTILS()).calcPart(feeOnTransfer, amount);   
        if(_fee <= amount){                
            amount -= _fee;
            _burn(sender, _fee);
        }
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        _checkEmission();
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "address err");
        totalSupply += amount;
        require(totalSupply <= maxSupply, "Maxxed");
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    function burn(uint256 amount) public virtual override {
        _burn(msg.sender, amount);
    }
    function burnFrom(address account, uint256 amount) public virtual {  
        uint256 decreasedAllowance = allowance(account, msg.sender) - (amount);
        _approve(account, msg.sender, decreasedAllowance); 
        _burn(account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "address err");
        require(_balances[account] >= amount, "balance err");
        _balances[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
    function flipEmissions() external onlyDAO {
        emitting = !emitting;
    }
    function flipMinting() external onlyDAO {
        minting = !minting;
    }
    function setParams(uint256 newTime, uint256 newCurve) external onlyDAO {
        secondsPerEra = newTime;
        emissionCurve = newCurve;
    }
    function saveFallenSpartans(address _savedSpartans, uint256 _saveAmount) external onlyDAO{
        require(!savedSpartans, 'spartans saved'); 
        savedSpartans = true;
        _mint(_savedSpartans, _saveAmount);
    }
    function changeDAO(address newDAO) external onlyDAO {
        require(newDAO != address(0), "address err");
        DAO = newDAO;
    }
    function purgeDAO() external onlyDAO {
        DAO = address(0);
    }
    function purgeDeployer() public onlyDAO {
        DEPLOYER = address(0);
    }
    function _checkEmission() private {
        if ((block.timestamp >= nextEraTime) && emitting) {    
            nextEraTime = block.timestamp + secondsPerEra; 
            uint256 _emission = getDailyEmission(); 
            _mint(RESERVE(), _emission); 
            feeOnTransfer = iUTILS(UTILS()).getFeeOnTransfer(totalSupply, maxSupply); 
            if (feeOnTransfer > 500) { 
                feeOnTransfer = 500; 
            } 
            emit NewEra(nextEraTime, _emission); 
        }
    }
    function getDailyEmission() public view returns (uint256) {
        uint _adjustedCap;
        if(totalSupply <= _100m){ 
            _adjustedCap = (maxSupply * totalSupply)/(_100m); 
        } else {
            _adjustedCap = maxSupply;  
        }
        return (_adjustedCap - totalSupply) / (emissionCurve); 
    }
    function upgrade() external {
        uint amount = iBEP20(BASEv1).balanceOf(msg.sender); 
        require(iBASEv1(BASEv1).transferTo(address(this), amount)); 
        iBEP20(BASEv1).burn(amount); 
        _mint(msg.sender, amount); 
    }
    function mintFromDAO(uint256 amount, address recipient) external onlyDAO {
        require(amount <= 5 * 10**6 * 10**decimals, '!5m'); 
        if(minting && (totalSupply <=  150 * 10**6 * 10**decimals)){ 
             _mint(recipient, amount); 
        }
    }
    function UTILS() internal view returns(address){
        return iDAO(DAO).UTILS();
    }
    function RESERVE() internal view returns(address){
        return iDAO(DAO).RESERVE(); 
    }
}