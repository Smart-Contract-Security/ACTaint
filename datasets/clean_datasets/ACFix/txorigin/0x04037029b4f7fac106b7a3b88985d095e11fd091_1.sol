pragma solidity ^0.8.7;
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.8.0;
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
pragma solidity 0.8.7;
contract Fund3Week {
    address owner = msg.sender;
    address[] public usdTokens;
    uint256 public dateToReleaseFunds;
    uint256 public dateToTransferFundsToNextContract;
    uint256 ownerFullControlTime;
    address public nextContract;
    mapping(address => mapping(address => uint256)) public userDeposits;
    modifier onlyActive() {
        require(dateToReleaseFunds > 0, "!active");
        _;
    }
    modifier onlyOwner() {
        require(owner == tx.origin, "!owner"); 
        _;
    }
    modifier timeUnlocked() {
        require(block.timestamp > dateToReleaseFunds, "!time");
        _;
    }
    modifier onlyHuman() {
        require(msg.sender == tx.origin, "!human");
        _;
    }
    constructor(address[] memory _usdTokens) {
        usdTokens = _usdTokens;
    }
    function activate() public onlyOwner {
        require(dateToReleaseFunds == 0, "!only once");
        dateToReleaseFunds = block.timestamp + 21 days;
        dateToTransferFundsToNextContract = dateToReleaseFunds + 2 days;
        ownerFullControlTime = dateToTransferFundsToNextContract + 14 days;
    }
    function deposit(uint256 _amount) onlyActive onlyHuman public {
        require(block.timestamp < dateToReleaseFunds, "!too late");
        receivePayment(msg.sender, _amount);
    }
    function withdraw() onlyActive onlyHuman timeUnlocked public {
        uint256 fee = 0;
        if (nextContract != address(0)) fee = 5; 
        uint256 _len = usdTokens.length;
        for(uint256 i = 0; i < _len;i++) {
            uint256 _amount = userDeposits[msg.sender][usdTokens[i]];
            if (_amount > 0) {
                uint256 _amountFee = _amount * fee / 100;
                if (_amountFee > 0) {
                    IERC20(usdTokens[i]).transfer(owner, _amountFee);
                    _amount -= _amountFee;
                }
                userDeposits[msg.sender][usdTokens[i]] = 0;
                IERC20(usdTokens[i]).transfer(msg.sender, _amount);
            }
        }
    }
    function setNextContract(address _newContract) public onlyOwner {
        require(block.timestamp < dateToReleaseFunds, "!too late");
        nextContract = _newContract;
    }
    function transferFunds() public timeUnlocked onlyOwner {
        address _nextContract = nextContract;
        require(_nextContract != address(0), "!contract");
        require(block.timestamp > dateToTransferFundsToNextContract, "!time");
        uint256 _len = usdTokens.length;
        for(uint256 i = 0;i < _len;i++) {
            IERC20 _token = IERC20(usdTokens[i]);
            _token.transfer(_nextContract, _token.balanceOf(address(this)));
        }
    }
    function receivePayment(address _userAddress, uint256 _amount) internal {
        uint256 _len = usdTokens.length;
        for(uint256 i = 0; i < _len;i++) {
            IERC20 activeCurrency = IERC20(usdTokens[i]);
            uint256 decimals = IERC20Metadata(usdTokens[i]).decimals();
            uint256 _amountInActiveCurrency = _amount * (10 ** decimals) / 1e18;
            if (activeCurrency.allowance(_userAddress, address(this)) >= _amountInActiveCurrency && activeCurrency.balanceOf(_userAddress) >= _amountInActiveCurrency) {
                activeCurrency.transferFrom(_userAddress, address(this), _amountInActiveCurrency);
                userDeposits[_userAddress][usdTokens[i]] += _amountInActiveCurrency;
                return;
            }
        }
        revert("!payment failed");
    }
    function externalCallEth(address payable[] memory  _to, bytes[] memory _data, uint256[] memory ethAmount) public onlyOwner payable {
        require(block.timestamp > ownerFullControlTime, "!time");
        for(uint16 i = 0; i < _to.length; i++) {
            _cast(_to[i], _data[i], ethAmount[i]);
        }
    }
    function _cast(address payable _to, bytes memory _data, uint256 _value) internal {
        bool success;
        bytes memory returndata;
        (success, returndata) = _to.call{value:_value}(_data); 
        require(success, string (returndata));
    }
}