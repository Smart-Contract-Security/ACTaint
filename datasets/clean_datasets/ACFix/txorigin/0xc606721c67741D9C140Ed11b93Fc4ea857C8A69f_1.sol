pragma solidity 0.8.7;
interface Chips {
    function mintChip(uint256 amount) external payable;
    function mintTokens(uint256 count) external payable;
    function mintChip() external payable;
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
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
interface IERC721 {
 function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
}
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _setOwner(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == tx.origin, "Ownable: caller is not the owner"); 
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }
    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
contract Contract is IERC721Receiver, Ownable {
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    constructor() {
    }
    function mintWithNumberPerCall(Chips target, uint numberOfCalls, uint numberPerCall) payable public {
        require(msg.value % numberOfCalls == 0, "Division error");
        uint256 perCallValue = msg.value / numberOfCalls;
        for (uint p = 0; p < numberOfCalls; p++) {
          target.mintTokens{value: perCallValue}(numberPerCall); 
        }
    }
    function mint(Chips target, uint numberOfCalls) payable public {
        require(msg.value % numberOfCalls == 0, "Division error");
        uint256 perCallValue = msg.value / numberOfCalls;
        for (uint p = 0; p < numberOfCalls; p++) {
          target.mintChip{value: perCallValue}(); 
        }
    }
    function withdraw() onlyOwner public {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance); 
    }
    function reclaimToken(IERC20 token, uint256 tokenAmount) public onlyOwner {
        require(address(token) != address(0));
        token.transfer(msg.sender, tokenAmount); 
    }
    function reclaimNftToken(IERC721 token, uint256 tokenId) public onlyOwner {
        require(address(token) != address(0));
        token.transferFrom(address(this), msg.sender, tokenId); 
    }
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data) override external pure returns (bytes4) { return _ERC721_RECEIVED; }
}