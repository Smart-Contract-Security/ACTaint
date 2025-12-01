pragma solidity ^0.8.4;
import "hardhat/console.sol";
enum FeeExemption {
  NO_EXEMPTIONS,
  SENDER_EXEMPT,
  SENDER_AND_RECEIVER_EXEMPT,
  REDEEM_EXEMPT_AND_SENDER_EXEMPT,
  REDEEM_EXEMPT_AND_SENDER_AND_RECEIVER_EXEMPT,
  RECEIVER_EXEMPT,
  REDEEM_EXEMPT_AND_RECEIVER_EXEMPT,
  REDEEM_EXEMPT_ONLY
}
interface IERC20 {
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
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
  event Transfer(address indexed from, address indexed to, uint128 value, uint128 burnt);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }
  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}
abstract contract ERC20 is Context, IERC20 {
  mapping(address => uint256) internal _balances;
  mapping(address => mapping(address => uint256)) internal _allowances;
  uint256 internal _totalSupply;
  string internal _name;
  string internal _symbol;
  function name() public view virtual override returns (string memory) {
    return _name;
  }
  function symbol() public view virtual override returns (string memory) {
    return _symbol;
  }
  function decimals() public view virtual override returns (uint8) {
    return 18;
  }
  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
  }
  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account];
  }
  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowances[owner][spender];
  }
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }
  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
    return true;
  }
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowances[_msgSender()][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
      _approve(_msgSender(), spender, currentAllowance - subtractedValue);
    }
    return true;
  }
  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual;
  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");
    _totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, uint128(amount), 0);
  }
  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: burn from the zero address");
    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
      _balances[account] = accountBalance - amount;
    }
    _totalSupply -= amount;
    emit Transfer(account, address(0), uint128(amount), 0);
  }
  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
  function burn(uint256 amount) public virtual {
    _burn(_msgSender(), amount);
  }
  function burnFrom(address account, uint256 amount) public virtual {
    uint256 currentAllowance = allowance(account, _msgSender());
    require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
    unchecked {
      _approve(account, _msgSender(), currentAllowance - amount);
    }
    _burn(account, amount);
  }
}
interface LiquidiyReceiverLike {
  function drain(address baseToken) external returns (uint256);
}
abstract contract ReentrancyGuard {
  uint256 private constant _NOT_ENTERED = 1;
  uint256 private constant _ENTERED = 2;
  uint256 private _status;
  constructor() {
    _status = _NOT_ENTERED;
  }
  modifier nonReentrant() {
    require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
    _status = _ENTERED;
    _;
    _status = _NOT_ENTERED;
  }
}
contract PyroToken is ERC20, ReentrancyGuard {
  struct Configuration {
    address liquidityReceiver;
    IERC20 baseToken;
    address loanOfficer;
    bool pullPendingFeeRevenue;
  }
  struct DebtObligation {
    uint256 base;
    uint256 pyro;
    uint256 redeemRate;
  }
  Configuration public config;
  uint256 private constant ONE = 1 ether;
  mapping(address => FeeExemption) feeExemptionStatus;
  mapping(address => DebtObligation) debtObligations;
  constructor() {
    config.liquidityReceiver = _msgSender();
    config.pullPendingFeeRevenue = true;
  }
  modifier initialized() {
    require(address(config.baseToken) != address(0), "PyroToken: base token not set");
    _;
  }
  function initialize(
    address baseToken,
    string memory name_,
    string memory symbol_
  ) public onlyReceiver {
    config.baseToken = IERC20(baseToken);
    _name = name_;
    _symbol = symbol_;
  }
  modifier onlyReceiver() {
    require(_msgSender() == config.liquidityReceiver, "PyroToken: Only Liquidity Receiver.");
    _;
  }
  modifier updateReserve() {
    if (config.pullPendingFeeRevenue) {
      LiquidiyReceiverLike(config.liquidityReceiver).drain(address(config.baseToken));
    }
    _;
  }
  modifier onlyLoanOfficer() {
    require(_msgSender() == config.loanOfficer, "PyroToken: Only Loan Officer.");
    _;
  }
  function setLoanOfficer(address loanOfficer) external onlyReceiver {
    config.loanOfficer = loanOfficer;
  }
  function togglePullPendingFeeRevenue(bool pullPendingFeeRevenue) external onlyReceiver {
    config.pullPendingFeeRevenue = pullPendingFeeRevenue;
  }
  function setFeeExemptionStatusFor(address exempt, FeeExemption status) public onlyReceiver {
    feeExemptionStatus[exempt] = status;
  }
  function transferToNewLiquidityReceiver(address liquidityReceiver) external onlyReceiver {
    require(liquidityReceiver != address(0), "PyroToken: New Liquidity Receiver cannot be the zero address.");
    config.liquidityReceiver = liquidityReceiver;
  }
  function mint(address recipient, uint256 baseTokenAmount) external updateReserve initialized returns (uint256) {
    uint256 _redeemRate = redeemRate();
    uint initialBalance = config.baseToken.balanceOf(address(this));
    require(config.baseToken.transferFrom(_msgSender(), address(this), baseTokenAmount));
    uint256 trueTransfer = config.baseToken.balanceOf(address(this)) - initialBalance;
    uint256 pyro = ( ONE* trueTransfer) / _redeemRate;
    console.log("minted pyro %s, baseTokenAmount %s", pyro, trueTransfer);
    _mint(recipient, pyro);
    emit Transfer(address(0), recipient, uint128(pyro), 0);
    return pyro;
  }
  function redeemFrom(
    address owner,
    address recipient,
    uint256 amount
  ) external returns (uint256) {
    uint256 currentAllowance = _allowances[owner][_msgSender()];
    _approve(owner, _msgSender(), currentAllowance - amount);
    return _redeem(owner, recipient, amount);
  }
  function redeem(address recipient, uint256 amount) external returns (uint256) {
    return _redeem(recipient, _msgSender(), amount);
  }
  function _redeem(
    address recipient,
    address owner,
    uint256 amount
  ) internal updateReserve returns (uint256) {
    uint256 _redeemRate = redeemRate();
    _balances[owner] -= amount;
    uint256 fee = calculateRedemptionFee(amount, owner);
    uint256 net = amount - fee;
    uint256 baseTokens = (net * ONE) / _redeemRate;
    _totalSupply -= amount;
    emit Transfer(owner, address(0), uint128(amount), uint128(amount));
    require(config.baseToken.transfer(recipient, baseTokens), "PyroToken reserve transfer failed.");
    return baseTokens;
  }
  function redeemRate() public view returns (uint256) {
    uint256 balanceOfBase = config.baseToken.balanceOf(address(this));
    if (_totalSupply == 0 || balanceOfBase == 0) return ONE;
    return (balanceOfBase * ONE) / _totalSupply;
  }
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);
    uint256 currentAllowance = _allowances[sender][_msgSender()];
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    unchecked {
      _approve(sender, _msgSender(), currentAllowance - amount);
    }
    return true;
  }
  function setObligationFor(
    address borrower,
    uint256 baseTokenBorrowed,
    uint256 pyroTokenStaked
  ) external onlyLoanOfficer nonReentrant returns (bool success) {
    DebtObligation memory currentDebt = debtObligations[borrower];
    uint256 rate = redeemRate();
    uint256 minPyroStake = (baseTokenBorrowed * ONE) / rate;
    require(pyroTokenStaked >= minPyroStake, "Pyro: Unsustainable loan.");
    debtObligations[borrower] = DebtObligation(baseTokenBorrowed, pyroTokenStaked, rate);
    int256 netStake = int256(pyroTokenStaked) - int256(currentDebt.pyro);
    uint256 stake;
    if (netStake > 0) {
      stake = uint256(netStake);
      uint256 currentAllowance = _allowances[borrower][_msgSender()];
      _approve(borrower, _msgSender(), currentAllowance - stake);
      _balances[borrower] -= stake;
      _balances[address(this)] += stake;
    } else if (netStake < 0) {
      stake = uint256(-netStake);
      _balances[borrower] += stake;
      _balances[address(this)] -= stake;
    }
    int256 netBorrowing = int256(baseTokenBorrowed) - int256(currentDebt.base);
    if (netBorrowing > 0) {
      config.baseToken.transfer(borrower, uint256(netBorrowing));
    } else if (netBorrowing < 0) {
      config.baseToken.transferFrom(borrower, address(this), uint256(-netBorrowing));
    }
    success = true;
  }
  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal override {
    if (recipient == address(0)) {
      burn(amount);
      return;
    }
    uint256 senderBalance = _balances[sender];
    uint256 fee = calculateTransferFee(amount, sender, recipient);
    _totalSupply -= fee;
    uint256 netReceived = amount - fee;
    _balances[sender] = senderBalance - amount;
    _balances[recipient] += netReceived;
    emit Transfer(sender, recipient, uint128(amount), uint128(fee)); 
  }
  function calculateTransferFee(
    uint256 amount,
    address sender,
    address receiver
  ) public view returns (uint256) {
    uint256 senderStatus = uint256(feeExemptionStatus[sender]);
    uint256 receiverStatus = uint256(feeExemptionStatus[receiver]);
    if (
      (senderStatus >= 1 && senderStatus <= 4) || (receiverStatus == 2 || (receiverStatus >= 4 && receiverStatus <= 6))
    ) {
      return 0;
    }
    return amount / 1000;
  }
  function calculateRedemptionFee(uint256 amount, address redeemer) public view returns (uint256) {
    uint256 status = uint256(feeExemptionStatus[redeemer]);
    if ((status >= 3 && status <= 4) || status > 5) return 0;
    return (amount * 2) / 100;
  }
}
abstract contract LiquidityReceiverLike {
  function setFeeExemptionStatusOnPyroForContract(
    address pyroToken,
    address target,
    FeeExemption exemption
  ) public virtual;
  function setPyroTokenLoanOfficer(address pyroToken, address loanOfficer) public virtual;
  function getPyroToken(address baseToken) public view virtual returns (address);
  function registerPyroToken(
    address baseToken,
    string memory name,
    string memory symbol
  ) public virtual;
  function drain(address baseToken) external virtual returns (uint256);
}
abstract contract SnufferCap {
  LiquidityReceiverLike public _liquidityReceiver;
  constructor(address liquidityReceiver) {
    _liquidityReceiver = LiquidityReceiverLike(liquidityReceiver);
  }
  function snuff(
    address pyroToken,
    address targetContract,
    FeeExemption exempt
  ) public virtual returns (bool);
  function _snuff(
    address pyroToken,
    address targetContract,
    FeeExemption exempt
  ) internal {
    _liquidityReceiver.setFeeExemptionStatusOnPyroForContract(pyroToken, targetContract, exempt);
  }
}
abstract contract Ownable {
  address private _owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  constructor() {
    _setOwner(msg.sender);
  }
  function owner() public view virtual returns (address) {
    return _owner;
  }
  modifier onlyOwner() {
    require(owner() == msg.sender, "Ownable: caller is not the owner");
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
abstract contract LachesisLike {
  function cut(address token) public view virtual returns (bool, bool);
  function measure(
    address token,
    bool valid,
    bool burnable
  ) public virtual;
}
library Create2 {
  function deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    address addr;
    assembly {
      addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
    }
    require(addr != address(0), "Create2: Failed on deploy");
    return addr;
  }
  function computeAddress(bytes32 salt, bytes memory bytecode) internal view returns (address) {
    return computeAddress(salt, bytecode, address(this));
  }
  function computeAddress(
    bytes32 salt,
    bytes memory bytecodeHash,
    address deployer
  ) internal pure returns (address) {
    bytes32 bytecodeHashHash = keccak256(bytecodeHash);
    bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHashHash));
    return address(bytes20(_data << 96));
  }
}
contract LiquidityReceiver is Ownable {
  struct Configuration {
    LachesisLike lachesis;
    SnufferCap snufferCap;
  }
  Configuration public config;
  bytes internal constant PYROTOKEN_BYTECODE = type(PyroToken).creationCode;
  modifier onlySnufferCap() {
    require(msg.sender == address(config.snufferCap), "LR: only snufferCap");
    _;
  }
  constructor(address _lachesis) {
    config.lachesis = LachesisLike(_lachesis);
  }
  function setSnufferCap(address snufferCap) public onlyOwner {
    config.snufferCap = SnufferCap(snufferCap);
  }
  function drain(address baseToken) external returns (uint256) {
    address pyroToken = getPyroToken(baseToken);
    IERC20 reserve = IERC20(baseToken);
    uint256 amount = reserve.balanceOf(address(this));
    reserve.transfer(pyroToken, amount);
    return amount;
  }
  function togglePyroTokenPullFeeRevenue(address pyroToken, bool pull) public onlyOwner {
    PyroToken(pyroToken).togglePullPendingFeeRevenue(pull);
  }
  function setPyroTokenLoanOfficer(address pyroToken, address loanOfficer) public onlyOwner {
    require(loanOfficer != address(0) && pyroToken != address(0), "LR: zero address detected");
    PyroToken(pyroToken).setLoanOfficer(loanOfficer);
  }
  function setLachesis(address _lachesis) public onlyOwner {
    config.lachesis = LachesisLike(_lachesis);
  }
  function setFeeExemptionStatusOnPyroForContract(
    address pyroToken,
    address target,
    FeeExemption exemption
  ) public onlySnufferCap {
    require(isContract(target), "LR: EOAs cannot be exempt.");
    PyroToken(pyroToken).setFeeExemptionStatusFor(target, exemption);
  }
  function registerPyroToken(
    address baseToken,
    string memory name,
    string memory symbol
  ) public onlyOwner {
    address expectedAddress = getPyroToken(baseToken);
    require(!isContract(expectedAddress), "PyroToken Address occupied");
    (bool valid, bool burnable) = config.lachesis.cut(baseToken);
    require(valid && !burnable, "PyroToken: invalid base token");
    address p = Create2.deploy(keccak256(abi.encode(baseToken)), PYROTOKEN_BYTECODE);
    PyroToken(p).initialize(baseToken, name, symbol);
    require(address(p) == expectedAddress, "PyroToken: address prediction failed");
  }
  function transferPyroTokenToNewReceiver(address pyroToken, address receiver) public onlyOwner {
    PyroToken(pyroToken).transferToNewLiquidityReceiver(receiver);
  }
  function getPyroToken(address baseToken) public view returns (address) {
    bytes32 salt = keccak256(abi.encode(baseToken));
    return Create2.computeAddress(salt, PYROTOKEN_BYTECODE);
  }
  function isContract(address addr) private view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(addr)
    }
    return size > 0;
  }
}