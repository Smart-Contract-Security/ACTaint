pragma solidity ^0.8.7;
contract TattooMoneyPublicSaleIV {
    uint256 private constant DECIMALS_TAT2 = 6;
    uint256 private constant DECIMALS_DAI = 18;
    uint256 private constant DECIMALS_USD = 6;
    uint256 private constant DECIMALS_WBTC = 8;
    uint256 public constant maxTokens = 1153846000000;
    uint256 public  dateStart;
    uint256 public  dateEnd;
    uint256 public usdCollected;
    uint256 public tokensLimit;
    uint256 public tokensSold;
    uint256 public tokensforadolar;
    address public tat2 = 0x960773318c1AeaB5dA6605C49266165af56435fa;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public wbtcoracle = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address public ethoracle = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public owner;
    address public newOwner;
    bool public saleEnded;
    mapping(address => uint256) private _deposited;
    mapping(address => uint256) public tokensBoughtOf;
    event AcceptedUSD(address indexed user, uint256 amount);
    event AcceptedWBTC(address indexed user, uint256 amount);
    event AcceptedETH(address indexed user, uint256 amount);
    string constant ERR_TRANSFER = "Token transfer failed";
    string constant ERR_SALE_LIMIT = "Token sale limit reached";
    string constant ERR_AML = "AML sale limit reached";
    string constant ERR_SOON = "TOO SOON";
    constructor(
        address _owner,
        uint256 _tokensLimit, 
        uint256 _startDate, 
        uint256 _endDate, 
        uint256 _tokensforadolar 
    ) {
        owner = _owner;
        tokensLimit = _tokensLimit * (10**DECIMALS_TAT2);
        dateStart = _startDate;
        dateEnd = _endDate;
        tokensforadolar = _tokensforadolar;
    }
    function payUSDC(uint256 amount) external {
        require(
            INterfaces(usdc).transferFrom(msg.sender, address(this), amount),
            ERR_TRANSFER
        );
        _pay(msg.sender, amount );
        _deposited[usdc] += amount;
    }
    function payUSDT(uint256 amount) external {
        INterfacesNoR(usdt).transferFrom(msg.sender, address(this), amount);
        _pay(msg.sender, amount );
        _deposited[usdt] += amount;
    }
    function payDAI(uint256 amount) external {
        require(
            INterfaces(dai).transferFrom(msg.sender, address(this), amount),
            ERR_TRANSFER
        );
        _pay(msg.sender, amount / (10**12));
        _deposited[dai] += amount;
    }
    function paywBTC(uint256 amount) external {
        require(
            INterfaces(wbtc).transferFrom(msg.sender, address(this), amount),
            ERR_TRANSFER
        );
        _paywBTC(msg.sender, amount );
        _deposited[wbtc] += amount;
    }
    receive() external payable {
        _payEth(msg.sender, msg.value);
    }
    function payETH() external payable {
        _payEth(msg.sender, msg.value);
    }
    function tokensPerEth() public view returns (uint256) {
        int256 answer;
        (, answer, , , ) = INterfaces(ethoracle).latestRoundData();
        return uint256((uint256(answer) * tokensforadolar)/10**8);
    }
    function tokensPerwBTC() public view returns (uint256) {
        int256 answer;
        (, answer, , , ) = INterfaces(wbtcoracle).latestRoundData();
        return uint256((uint256(answer) * tokensforadolar)/10**8);
    }
    function tokensLeft() external view returns (uint256) {
        return tokensLimit - tokensSold;
    }
    function _payEth(address user, uint256 amount) internal notEnded {
        uint256 sold = (amount * tokensPerEth()) / (10**18);
        tokensSold += sold;
        require(tokensSold <= tokensLimit, ERR_SALE_LIMIT);
        tokensBoughtOf[user] += sold;
        require(tokensBoughtOf[user] <= maxTokens, ERR_AML);
        _sendTokens(user, sold);
        emit AcceptedETH(user, amount);
    }
    function _paywBTC(address user, uint256 amount) internal notEnded {
        uint256 sold = (amount * tokensPerwBTC()) / (10**8);
        tokensSold += sold;
        require(tokensSold <= tokensLimit, ERR_SALE_LIMIT);
        tokensBoughtOf[user] += sold;
        require(tokensBoughtOf[user] <= maxTokens, ERR_AML);
        _sendTokens(user, sold);
        emit AcceptedWBTC(user, amount);
    }
    function _pay(address user, uint256 usd) internal notEnded {
        uint256 sold = (usd * tokensforadolar) / (10**6);
        tokensSold += sold;
        require(tokensSold <= tokensLimit, ERR_SALE_LIMIT);
        tokensBoughtOf[user] += sold;
        require(tokensBoughtOf[user] <= maxTokens, ERR_AML);
        _sendTokens(user, sold);
        emit AcceptedUSD(user, usd);
    }
    function _sendTokens(address user, uint256 amount) internal notEnded {
      require(
          INterfaces(tat2).transfer(user, amount),
          ERR_TRANSFER
      );
    }
    modifier notEnded() {
        require(!saleEnded, "Sale ended");
        require(
            block.timestamp > dateStart && block.timestamp < dateEnd,
            "Too soon or too late"
        );
        _;
    }
    modifier onlyOwner() {
        require(tx.origin == owner, "Only for contract Owner"); 
        _;
    }
    function takeAll() external onlyOwner {
        uint256 amt = INterfaces(usdt).balanceOf(address(this));
        if (amt > 0) {
            INterfacesNoR(usdt).transfer(owner, amt);
        }
        amt = INterfaces(usdc).balanceOf(address(this));
        if (amt > 0) {
            require(INterfaces(usdc).transfer(owner, amt), ERR_TRANSFER);
        }
        amt = INterfaces(dai).balanceOf(address(this));
        if (amt > 0) {
            require(INterfaces(dai).transfer(owner, amt), ERR_TRANSFER);
        }
        amt = INterfaces(wbtc).balanceOf(address(this));
        if (amt > 0) {
            require(INterfaces(wbtc).transfer(owner, amt), ERR_TRANSFER);
        }
        amt = INterfaces(tat2).balanceOf(address(this));
        if (amt > 0) {
            require(INterfaces(tat2).transfer(owner, amt), ERR_TRANSFER);
        }
        amt = address(this).balance;
        if (amt > 0) {
            payable(owner).transfer(amt);
        }
    }
    function recoverErc20(address token) external onlyOwner {
        uint256 amt = INterfaces(token).balanceOf(address(this));
        if (amt > 0) {
            INterfacesNoR(token).transfer(owner, amt);  
        }
    }
    function recoverEth() external onlyOwner {
        payable(owner).transfer(address(this).balance); 
    }
    function EndSale() external onlyOwner {
        saleEnded = true;
    }
    function changeOwner(address _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() external {
        require(
            msg.sender != address(0) && msg.sender == newOwner,
            "Only NewOwner"
        );
        newOwner = address(0);
        owner = msg.sender;
    }
}
interface INterfaces {
    function balanceOf(address) external returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
interface INterfacesNoR {
    function transfer(address, uint256) external;
    function transferFrom(
        address,
        address,
        uint256
    ) external;
}