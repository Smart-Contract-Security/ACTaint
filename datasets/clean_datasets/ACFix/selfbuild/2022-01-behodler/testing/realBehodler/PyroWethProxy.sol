pragma solidity 0.8.4;
import "hardhat/console.sol";
contract Ownable {
  address private _owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  constructor() {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), msg.sender);
  }
  function owner() public view returns (address) {
    return _owner;
  }
  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not the owner");
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
pragma solidity 0.8.4;
abstract contract PyroTokenLike {
  function config()
    public
    virtual
    returns (
      address,
      address,
      address,
      bool
    );
  function redeem(uint256 pyroTokenAmount) external virtual returns (uint256);
  function mint(uint256 baseTokenAmount) external payable virtual returns (uint256);
  function redeemRate() public view virtual returns (uint256);
}
pragma solidity 0.8.4;
interface IERC20 {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function decimals() external returns (uint8);
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
pragma solidity 0.8.4;
interface IERC2612 {
  function permit(
    address owner,
    address spender,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
  function nonces(address owner) external view returns (uint256);
}
interface IERC3156FlashBorrower {
  function onFlashLoan(
    address initiator,
    address token,
    uint256 amount,
    uint256 fee,
    bytes calldata data
  ) external returns (bytes32);
}
interface IERC3156FlashLender {
  function maxFlashLoan(address token) external view returns (uint256);
  function flashFee(address token, uint256 amount) external view returns (uint256);
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address token,
    uint256 amount,
    bytes calldata data
  ) external returns (bool);
}
interface IWETH10 is IERC20, IERC2612, IERC3156FlashLender {
  function flashMinted() external view returns (uint256);
  function deposit() external payable;
  function depositTo(address to) external payable;
  function withdraw(uint256 value) external;
  function withdrawTo(address payable to, uint256 value) external;
  function withdrawFrom(
    address from,
    address payable to,
    uint256 value
  ) external;
  function depositToAndCall(address to, bytes calldata data) external payable returns (bool);
  function approveAndCall(
    address spender,
    uint256 value,
    bytes calldata data
  ) external returns (bool);
  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool);
}
interface ITransferReceiver {
  function onTokenTransfer(
    address,
    uint256,
    bytes calldata
  ) external returns (bool);
}
interface IApprovalReceiver {
  function onTokenApproval(
    address,
    uint256,
    bytes calldata
  ) external returns (bool);
}
contract WETH10 is IWETH10 {
  string public constant override name = "WETH10";
  string public constant override symbol = "WETH10";
  uint8 public constant override decimals = 18;
  bytes32 public immutable CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
  bytes32 public immutable PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  mapping(address => uint256) public override balanceOf;
  mapping(address => uint256) public override nonces;
  mapping(address => mapping(address => uint256)) public override allowance;
  uint256 public override flashMinted;
  function totalSupply() external view override returns (uint256) {
    return address(this).balance + flashMinted;
  }
  receive() external payable {
    balanceOf[msg.sender] += msg.value;
    emit Transfer(address(0), msg.sender, msg.value);
  }
  function deposit() external payable override {
    balanceOf[msg.sender] += msg.value;
    emit Transfer(address(0), msg.sender, msg.value);
  }
  function depositTo(address to) external payable override {
    balanceOf[to] += msg.value;
    emit Transfer(address(0), to, msg.value);
  }
  function depositToAndCall(address to, bytes calldata data) external payable override returns (bool success) {
    balanceOf[to] += msg.value;
    emit Transfer(address(0), to, msg.value);
    return ITransferReceiver(to).onTokenTransfer(msg.sender, msg.value, data);
  }
  function maxFlashLoan(address token) external view override returns (uint256) {
    return token == address(this) ? type(uint112).max - flashMinted : 0; 
  }
  function flashFee(address token, uint256) external view override returns (uint256) {
    require(token == address(this), "WETH: flash mint only WETH10");
    return 0;
  }
  function flashLoan(
    IERC3156FlashBorrower receiver,
    address token,
    uint256 value,
    bytes calldata data
  ) external override returns (bool) {
    require(token == address(this), "WETH: flash mint only WETH10");
    require(value <= type(uint112).max, "WETH: individual loan limit exceeded");
    flashMinted = flashMinted + value;
    require(flashMinted <= type(uint112).max, "WETH: total loan limit exceeded");
    balanceOf[address(receiver)] += value;
    emit Transfer(address(0), address(receiver), value);
    require(
      receiver.onFlashLoan(msg.sender, address(this), value, 0, data) == CALLBACK_SUCCESS,
      "WETH: flash loan failed"
    );
    uint256 allowed = allowance[address(receiver)][address(this)];
    if (allowed != type(uint256).max) {
      require(allowed >= value, "WETH: request exceeds allowance");
      uint256 reduced = allowed - value;
      allowance[address(receiver)][address(this)] = reduced;
      emit Approval(address(receiver), address(this), reduced);
    }
    uint256 balance = balanceOf[address(receiver)];
    require(balance >= value, "WETH: burn amount exceeds balance");
    balanceOf[address(receiver)] = balance - value;
    emit Transfer(address(receiver), address(0), value);
    flashMinted = flashMinted - value;
    return true;
  }
  function withdraw(uint256 value) external override {
    uint256 balance = balanceOf[msg.sender];
    require(balance >= value, "WETH: burn amount exceeds balance");
    balanceOf[msg.sender] = balance - value;
    emit Transfer(msg.sender, address(0), value);
    (bool success, ) = msg.sender.call{value: value}("");
    require(success, "WETH: ETH transfer failed");
  }
  function withdrawTo(address payable to, uint256 value) external override {
    uint256 balance = balanceOf[msg.sender];
    require(balance >= value, "WETH: burn amount exceeds balance");
    balanceOf[msg.sender] = balance - value;
    emit Transfer(msg.sender, address(0), value);
    (bool success, ) = to.call{value: value}("");
    require(success, "WETH: ETH transfer failed");
  }
  function withdrawFrom(
    address from,
    address payable to,
    uint256 value
  ) external override {
    if (from != msg.sender) {
      uint256 allowed = allowance[from][msg.sender];
      if (allowed != type(uint256).max) {
        require(allowed >= value, "WETH: request exceeds allowance");
        uint256 reduced = allowed - value;
        allowance[from][msg.sender] = reduced;
        emit Approval(from, msg.sender, reduced);
      }
    }
    uint256 balance = balanceOf[from];
    require(balance >= value, "WETH: burn amount exceeds balance");
    balanceOf[from] = balance - value;
    emit Transfer(from, address(0), value);
    (bool success, ) = to.call{value: value}("");
    require(success, "WETH: Ether transfer failed");
  }
  function approve(address spender, uint256 value) external override returns (bool) {
    allowance[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }
  function approveAndCall(
    address spender,
    uint256 value,
    bytes calldata data
  ) external override returns (bool) {
    allowance[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return IApprovalReceiver(spender).onTokenApproval(msg.sender, value, data);
  }
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override {
    require(block.timestamp <= deadline, "WETH: Expired permit");
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    bytes32 DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes("1")),
        chainId,
        address(this)
      )
    );
    bytes32 hashStruct = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline));
    bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashStruct));
    address signer = ecrecover(hash, v, r, s);
    require(signer != address(0) && signer == owner, "WETH: invalid permit");
    allowance[owner][spender] = value;
    emit Approval(owner, spender, value);
  }
  function transfer(address to, uint256 value) external override returns (bool) {
    if (to != address(0)) {
      uint256 balance = balanceOf[msg.sender];
      require(balance >= value, "WETH: transfer amount exceeds balance");
      balanceOf[msg.sender] = balance - value;
      balanceOf[to] += value;
      emit Transfer(msg.sender, to, value);
    } else {
      uint256 balance = balanceOf[msg.sender];
      require(balance >= value, "WETH: burn amount exceeds balance");
      balanceOf[msg.sender] = balance - value;
      emit Transfer(msg.sender, address(0), value);
      (bool success, ) = msg.sender.call{value: value}("");
      require(success, "WETH: ETH transfer failed");
    }
    return true;
  }
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external override returns (bool) {
    if (from != msg.sender) {
      uint256 allowed = allowance[from][msg.sender];
      if (allowed != type(uint256).max) {
        if (allowed < value) {
          console.log("FROM: %s TO: %s", from, to);
          console.log("allowed: %s value: %s", allowed, value);
        }
        require(allowed >= value, "WETH: request exceeds allowance");
        uint256 reduced = allowed - value;
        allowance[from][msg.sender] = reduced;
        emit Approval(from, msg.sender, reduced);
      }
    }
    if (to != address(0)) {
      uint256 balance = balanceOf[from];
      require(balance >= value, "WETH: transfer amount exceeds balance");
      balanceOf[from] = balance - value;
      balanceOf[to] += value;
      emit Transfer(from, to, value);
    } else {
      uint256 balance = balanceOf[from];
      require(balance >= value, "WETH: burn amount exceeds balance");
      balanceOf[from] = balance - value;
      emit Transfer(from, address(0), value);
      (bool success, ) = msg.sender.call{value: value}("");
      require(success, "WETH: ETH transfer failed");
    }
    return true;
  }
  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external override returns (bool) {
    if (to != address(0)) {
      uint256 balance = balanceOf[msg.sender];
      require(balance >= value, "WETH: transfer amount exceeds balance");
      balanceOf[msg.sender] = balance - value;
      balanceOf[to] += value;
      emit Transfer(msg.sender, to, value);
    } else {
      uint256 balance = balanceOf[msg.sender];
      require(balance >= value, "WETH: burn amount exceeds balance");
      balanceOf[msg.sender] = balance - value;
      emit Transfer(msg.sender, address(0), value);
      (bool success, ) = msg.sender.call{value: value}("");
      require(success, "WETH: ETH transfer failed");
    }
    return ITransferReceiver(to).onTokenTransfer(msg.sender, value, data);
  }
}
contract PyroWeth10Proxy is Ownable {
  IWETH10 public weth10;
  uint256 constant ONE = 1e18;
  bool unlocked = true;
  address public baseToken;
  modifier reentrancyGuard() {
    require(unlocked, "PyroProxy: reentrancy guard active");
    unlocked = false;
    _;
    unlocked = true;
  }
  constructor(address pyroWeth) {
    baseToken = pyroWeth;
    (, address weth, , ) = PyroTokenLike(pyroWeth).config();
    weth10 = IWETH10(weth);
    IERC20(weth10).approve(baseToken, type(uint256).max);
  }
  function balanceOf(address holder) external view returns (uint256) {
    return IERC20(baseToken).balanceOf(holder);
  }
  function redeem(uint256 pyroTokenAmount) external reentrancyGuard returns (uint256) {
    IERC20(baseToken).transferFrom(msg.sender, address(this), pyroTokenAmount); 
    uint256 actualAmount = IERC20(baseToken).balanceOf(address(this));
    PyroTokenLike(baseToken).redeem(actualAmount);
    uint256 balanceOfWeth = weth10.balanceOf(address(this));
    weth10.withdrawTo(payable(msg.sender), balanceOfWeth);
    return balanceOfWeth;
  }
  function mint(uint256 baseTokenAmount) external payable reentrancyGuard returns (uint256) {
    require(msg.value == baseTokenAmount && baseTokenAmount > 0, "PyroWethProxy: amount invariant");
    weth10.deposit{value: msg.value}();
    uint256 weth10Balance = weth10.balanceOf(address(this));
    PyroTokenLike(baseToken).mint(weth10Balance);
    uint256 pyroWethBalance = IERC20(baseToken).balanceOf(address(this));
    IERC20(baseToken).transfer(msg.sender, pyroWethBalance);
    return (pyroWethBalance * 999) / 1000; 
  }
  function calculateMintedPyroWeth(uint256 baseTokenAmount) external view returns (uint256) {
    uint256 pyroTokenRedeemRate = PyroTokenLike(baseToken).redeemRate();
    uint256 mintedPyroTokens = (baseTokenAmount * ONE) / (pyroTokenRedeemRate);
    return (mintedPyroTokens * 999) / 1000; 
  }
  function calculateRedeemedWeth(uint256 pyroTokenAmount) external view returns (uint256) {
    uint256 pyroTokenSupply = IERC20(baseToken).totalSupply() - ((pyroTokenAmount * 1) / 1000);
    uint256 wethBalance = IERC20(weth10).balanceOf(baseToken);
    uint256 newRedeemRate = (wethBalance * ONE) / pyroTokenSupply;
    uint256 newPyroTokenbalance = (pyroTokenAmount * 999) / 1000;
    uint256 fee = (newPyroTokenbalance * 2) / 100;
    uint256 net = newPyroTokenbalance - fee;
    return (net * newRedeemRate) / ONE;
  }
  function redeemRate() public view returns (uint256) {
    return PyroTokenLike(baseToken).redeemRate();
  }
}