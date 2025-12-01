pragma solidity ^0.7.0;
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
pragma solidity ^0.7.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
}
pragma solidity ^0.7.0;
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == tx.origin, "Ownable: caller is not the owner"); 
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
pragma solidity ^0.7.0;
contract TokenRecover is Ownable {
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount); 
    }
}
pragma solidity ^0.7.0;
contract ServiceReceiver is TokenRecover {
    mapping (bytes32 => uint256) private _prices;
    event Created(string serviceName, address indexed serviceAddress);
    function pay(string memory serviceName) public payable {
        require(msg.value == _prices[_toBytes32(serviceName)], "ServiceReceiver: incorrect price");
        emit Created(serviceName, _msgSender());
    }
    function getPrice(string memory serviceName) public view returns (uint256) {
        return _prices[_toBytes32(serviceName)];
    }
    function setPrice(string memory serviceName, uint256 amount) public onlyOwner {
        _prices[_toBytes32(serviceName)] = amount;
    }
    function withdraw(uint256 amount) public onlyOwner {
        payable(owner()).transfer(amount); 
    }
    function _toBytes32(string memory serviceName) private pure returns (bytes32) {
        return keccak256(abi.encode(serviceName));
    }
}