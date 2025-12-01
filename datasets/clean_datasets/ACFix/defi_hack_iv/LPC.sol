pragma solidity ^0.8.0;
interface IRlinkCore {
    function addRelation(address _child, address _parent) external returns(uint256);
    function isParent(address child,address parent) external view returns(bool);
    function parentOf(address account) external view returns(address);
    function distribute(
        address token,
        address to,
        uint256 amount,
        uint256 incentiveAmount,
        uint256 parentAmount,
        uint256 grandpaAmount
    ) external returns(uint256 distributedAmount);
}
pragma solidity ^0.8.0;
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
pragma solidity ^0.8.0;
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
pragma solidity ^0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        this; 
        return msg.data;
    }
}
pragma solidity ^0.8.0;
abstract contract Pausable is Context {
    event Paused(address account);
    event Unpaused(address account);
    bool private _paused;
    constructor() {
        _paused = false;
    }
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}
pragma solidity ^0.8.0;
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
pragma solidity ^0.8.0;
abstract contract BlackListable is Ownable {
    function getBlackListStatus(address _maker) public view returns (bool) {
        return isBlackListed[_maker];
    }
    mapping (address => bool) public isBlackListed;
    function addBlackList(address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }
    function removeBlackList(address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }
    modifier notBlackListed {
        require(!isBlackListed[_msgSender()],"BlackListable: blacklisted");
        _;
    }
    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);
}
pragma solidity ^0.8.0;
library SafeCast {
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}
pragma solidity ^0.8.0;
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
pragma solidity ^0.8.0;
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }
    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
pragma solidity ^0.8.0;
contract LPC is Ownable,Pausable,BlackListable, IERC20Metadata {
    using Address for address;
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    string private constant _name = "LPC";
    string private constant _symbol = "LPC";
    uint256 private _totalSupply = 100000000 * 1e18;
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping (address => uint) public nonces;
    address private constant _blackHole = address(0);
    mapping(address => bool) public isWhiteList;
    IRlinkCore public immutable rlink;
    uint256 public rewardPerHolderStored;
    mapping(address => uint256) public userRewardPerHolderPaid;
    uint256 public totalHolders;
    RateConfig public feeRates;
    address public feeTo;
    struct RateConfig {
        uint32 burnRate;
        uint32 feeRate;
        uint32 parentRate;
        uint32 grandpaRate;
        uint32 holdersRate;
        uint96 burnStopSupply;
    }
    struct FeeAmounts {
        uint256 burnAmount;
        uint256 feeAmount;
        uint256 holdersAmount;
        uint256 parentAmount;
        uint256 grandpaAmount;
    }
    event ParentsRewardsPaid(address child,address parent,uint reward,bool isDirect);
    event DividendsPaid(uint amount,uint holdersCount);
    constructor(
        address _rlink
    ){
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(_name)), _getChainId(), address(this)));
        rlink = IRlinkCore(_rlink);
        setFeeTo(address(0xBEc385af40626199D92C402E600f054e157DfA7b));
        setFeeRates(2*1e7, 15*1e6, 2*1e7, 15*1e6, 1*1e7, 21000000*1e18);
        isWhiteList[msg.sender] = true;
        _balances[msg.sender] = _totalSupply;
        totalHolders = 1;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    function name() public pure override returns (string memory) {
        return _name;
    }
    function symbol() public pure override returns (string memory) {
        return _symbol;
    }
    function decimals() public pure override returns (uint8) {
        return 18;
    }
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint256) {
        uint capital = _balances[account];
        if(capital == 0){
            return 0;
        }
        return _isValidRewardHolder(account) ? capital.add(calcPendingReward(account)) : capital;
    }
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function permit(address owner, address spender, uint amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp <= deadline, "ERC20permit: expired");
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, amount, nonces[owner]++, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "ERC20permit: invalid signature");
        require(signatory == owner, "ERC20permit: unauthorized");
        _approve(owner, spender, amount);
    }
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
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
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(!isBlackListed[sender] && !isBlackListed[recipient],"sender or recipient is blacklisted");
        _beforeTokenTransfer(sender, recipient, amount);
        uint totalHolders_ = totalHolders;
        (bool vs,uint senderBalance) = _updateBalance(sender);
        (bool vr,uint recipientBalance) = _updateBalance(recipient);
        if(vs && senderBalance == amount){
            totalHolders_ = totalHolders_ - 1;
        }
        if(vr && recipientBalance == 0){
            totalHolders_ = totalHolders_ + 1;
        }
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        uint recipientAmount = amount;
        if(sender != address(0) && recipient != address(0) && !isWhiteList[sender] && !isWhiteList[recipient]){
            FeeAmounts memory feeAmounts = _calcTransferFees(amount);
            if(feeAmounts.feeAmount > 0){
                recipientAmount = recipientAmount - feeAmounts.feeAmount;
                address feeTo_ = feeTo;
                (,uint feeToCapital) = _updateBalance(feeTo_);
                if(feeToCapital == 0){
                    totalHolders_ += 1;
                }
                _balances[feeTo_] = feeToCapital.add(feeAmounts.feeAmount);
                emit Transfer(sender, feeTo_, feeAmounts.feeAmount);
            }
            if(feeAmounts.parentAmount + feeAmounts.grandpaAmount > 0){
                address parent = rlink.parentOf(recipient);
                if(parent != address(0)){
                    if(feeAmounts.parentAmount > 0){
                        recipientAmount = recipientAmount - feeAmounts.parentAmount;
                        (bool v,uint pb) = _updateBalance(parent);
                        if(v && pb == 0){
                            totalHolders_ += 1;
                        }
                        _balances[parent] = pb.add(feeAmounts.parentAmount);
                        emit Transfer(sender, parent, feeAmounts.parentAmount);
                        emit ParentsRewardsPaid(recipient,parent,feeAmounts.parentAmount,true);
                    }
                    if(feeAmounts.grandpaAmount > 0){
                        address grandpa = rlink.parentOf(parent);
                        if(grandpa != address(0)){
                            recipientAmount = recipientAmount - feeAmounts.grandpaAmount;
                            (bool v,uint gb) = _updateBalance(grandpa);
                            if(v && gb==0){
                                totalHolders_ += 1;
                            }
                            _balances[grandpa] = gb.add(feeAmounts.grandpaAmount);
                            emit Transfer(sender, grandpa, feeAmounts.grandpaAmount);
                            emit ParentsRewardsPaid(recipient,grandpa,feeAmounts.grandpaAmount,false);
                        }else{
                            feeAmounts.burnAmount = feeAmounts.burnAmount + feeAmounts.grandpaAmount;
                        }
                    }
                }else{
                    feeAmounts.burnAmount = feeAmounts.burnAmount + feeAmounts.parentAmount + feeAmounts.grandpaAmount;
                }
            }
            if(feeAmounts.holdersAmount > 0){
                if(totalHolders_ > 0){
                    recipientAmount = recipientAmount - feeAmounts.holdersAmount;
                    rewardPerHolderStored = rewardPerHolderStored + feeAmounts.holdersAmount / totalHolders_;
                    emit DividendsPaid(feeAmounts.holdersAmount,totalHolders_);
                }
            }
            if(feeAmounts.burnAmount > 0){
                recipientAmount = recipientAmount - feeAmounts.burnAmount;
                _balances[_blackHole] = _balances[_blackHole] + feeAmounts.burnAmount;
                emit Transfer(sender, _blackHole, feeAmounts.burnAmount);
            }
        }
        totalHolders = totalHolders_;
        _balances[sender] = senderBalance.sub(amount);
        _balances[recipient] = recipientBalance.add(recipientAmount);
        emit Transfer(sender, recipient, recipientAmount);
        _afterTokenTransfer(sender, recipient, amount);
    }
    function earened(address account) public view returns(uint256){
        return account != address(0) && !account.isContract() ? calcPendingReward(account) : 0;
    }
    function calcPendingReward(address account) public view returns(uint256){
        return rewardPerHolderStored.sub(userRewardPerHolderPaid[account]);
    }
    function _updateBalance(address account) internal returns(bool,uint) {
        bool isValid = _isValidRewardHolder(account);
        uint capital = _balances[account];
        uint pendingReward = 0;
        if(isValid){
            if(capital > 0){
                pendingReward = calcPendingReward(account);
                if(pendingReward > 0){
                    _balances[account] = capital.add(pendingReward);
                }
            }
            userRewardPerHolderPaid[account] = rewardPerHolderStored;
        }
         return (isValid,capital.add(pendingReward));
    }
    function _calcTransferFees(uint amount) internal view returns(FeeAmounts memory fees) {
        RateConfig memory rates_ = feeRates;
        uint burnCap = _totalSupply - rates_.burnStopSupply;
        fees.burnAmount = amount.mul(rates_.burnRate).div(1e9);
        uint burnedAmount = balanceOf(_blackHole);
        if(fees.burnAmount.add(burnedAmount) > burnCap){
            fees.burnAmount = burnCap > burnedAmount ? burnCap - burnedAmount : 0;
        }
        fees.feeAmount = amount.mul(rates_.feeRate).div(1e9);
        fees.holdersAmount = amount.mul(rates_.holdersRate).div(1e9);
        fees.parentAmount = amount.mul(rates_.parentRate).div(1e9);
        fees.grandpaAmount = amount.mul(rates_.grandpaRate).div(1e9);
    }
    function _isValidRewardHolder(address _account) internal view returns(bool){
        return _account != address(0) && !_account.isContract();
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal whenNotPaused {}
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {}
    function _getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
    function mint(address to,uint256 amount) public onlyOwner {
        require(amount > 0,"amount can not be 0");
        uint balance = balanceOf(to);
        if(balance == 0){
            totalHolders = totalHolders.add(1);
        }
        _mint(to, amount);
    }
    function burn(address account, uint256 amount) public onlyOwner {
        require(amount > 0,"amount can not be 0");
        if(!account.isContract()){
            uint balance = balanceOf(account);
            if(balance == amount){
                totalHolders = totalHolders.sub(1);
            }
        }
        _burn(account, amount);
    }
    function addWhiteList(address account) external onlyOwner {
        require(account != address(0),"account can not be address 0");
        isWhiteList[account] = true;
    }
    function removeWhiteList(address account) external onlyOwner {
        require(account != address(0),"account can not be address 0");
        isWhiteList[account] = false;
    }
    function setFeeRates(uint burnRate,uint feeRate,uint holdersRate,uint parentRate,uint grandpaRate,uint burnStopSupply) public onlyOwner {
        require(burnRate.add(feeRate).add(holdersRate).add(parentRate).add(grandpaRate) <= 1e9,"sum of rates can not greater than 1e9");
        require(burnStopSupply <= _totalSupply,"burn stop supply can not greater than total supply");
        feeRates = RateConfig({
            burnRate: SafeCast.toUint32(burnRate),
            feeRate: SafeCast.toUint32(feeRate),
            holdersRate: SafeCast.toUint32(holdersRate),
            parentRate: SafeCast.toUint32(parentRate),
            grandpaRate: SafeCast.toUint32(grandpaRate),
            burnStopSupply: SafeCast.toUint96(burnStopSupply)
        });
    }
    function setFeeTo(address _feeTo) public onlyOwner {
        require(_feeTo != address(0) && !Address.isContract(_feeTo),"fee to can not be address 0 or contract address");
        feeTo = _feeTo;
        isWhiteList[_feeTo] = true;
    }
    function pause() public onlyOwner {
        _pause();
    }
    function unpause() public onlyOwner {
       _unpause();
    }
}