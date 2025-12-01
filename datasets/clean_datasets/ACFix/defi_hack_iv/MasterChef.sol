pragma solidity >=0.6.0 <0.8.0;
abstract contract Proxy {
    function _delegate(address implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    function _implementation() internal view virtual returns (address);
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }
    fallback () external payable virtual {
        _fallback();
    }
    receive () external payable virtual {
        _fallback();
    }
    function _beforeFallback() internal virtual {
    }
}
pragma solidity 0.6.12;
contract ParaProxyAdminStorage {
    address public admin;
    address public pendingAdmin;
    address public implementation;
    address public pendingImplementation;
}
pragma solidity 0.6.12;
contract ParaProxy is ParaProxyAdminStorage, Proxy{
    event NewPendingImplementation(address oldPendingImplementation, address newPendingImplementation);
    event NewImplementation(address oldImplementation, address newImplementation);
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewAdmin(address oldAdmin, address newAdmin);
    constructor() public {
        admin = msg.sender;
    }
    function _setPendingImplementation(address newPendingImplementation) public returns (uint) {
        require(msg.sender == admin, "auth");
        address oldPendingImplementation = pendingImplementation;
        pendingImplementation = newPendingImplementation;
        emit NewPendingImplementation(oldPendingImplementation, pendingImplementation);
        return 0;
    }
    function _acceptImplementation() public returns (uint) {
        if (msg.sender != pendingImplementation || pendingImplementation == address(0)) {
            return 1;
        }
        address oldImplementation = implementation;
        address oldPendingImplementation = pendingImplementation;
        implementation = pendingImplementation;
        pendingImplementation = address(0);
        emit NewImplementation(oldImplementation, implementation);
        emit NewPendingImplementation(oldPendingImplementation, pendingImplementation);
        return 0;
    }
    function _setPendingAdmin(address newPendingAdmin) public returns (uint) {
        if (msg.sender != admin) {
            return 1;
        }
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = newPendingAdmin;
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
        return 0;
    }
    function _acceptAdmin() public returns (uint) {
        if (msg.sender != pendingAdmin || msg.sender == address(0)) {
            return 1;
        }
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
        return 0;
    }
    function _implementation() internal view virtual override returns (address){
        return implementation;
    }
}
pragma solidity ^0.6.6;
interface IFeeDistributor {
    function incomeClaimFee(address user, address token, uint256 fee) external;
    function incomeWithdrawFee(address user, address token, uint256 fee, uint256 amount) external;
    function incomeSwapFee(address user, address token, uint256 fee) payable external;
    function setReferalByChef(address user, address referal) external;
}
pragma solidity >=0.6.0;
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: BNB_TRANSFER_FAILED');
    }
}
pragma solidity >=0.5.0;
interface IParaPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function initialize(address, address) external;
}
pragma solidity >=0.6.2;
interface IParaRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}
pragma solidity >=0.6.2;
interface IParaRouter02 is IParaRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}
pragma solidity >=0.5.0;
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}
pragma solidity >=0.6.0 <0.8.0;
library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping (bytes32 => uint256) _indexes;
    }
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) { 
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            bytes32 lastvalue = set._values[lastIndex];
            set._values[toDeleteIndex] = lastvalue;
            set._indexes[lastvalue] = toDeleteIndex + 1; 
            set._values.pop();
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }
    struct Bytes32Set {
        Set _inner;
    }
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }
    struct AddressSet {
        Set _inner;
    }
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }
    struct UintSet {
        Set _inner;
    }
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}
pragma solidity >=0.6.2 <0.8.0;
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
library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}
pragma solidity >=0.5.0;
interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}
pragma solidity >=0.6.0 <0.8.0;
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { 
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
pragma solidity >=0.6.0 <0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes memory) {
        this; 
        return msg.data;
    }
}
pragma solidity >=0.6.0 <0.8.0;
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () internal {
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
pragma solidity >=0.6.0 <0.8.0;
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}
pragma solidity 0.6.12;
contract ParaToken is ERC20("ParalUni Token", "T42"), Ownable {
    using SafeMath for uint256;
    uint denominator = 1e18;
    uint256 public hardLimit = 10000000000e18; 
    uint256 public _issuePerBlock = 1150e18;   
    uint256 public startBlock;          
    uint256 public lastBlockHalve;             
    uint256 public lastSoftLimit = 0;          
    uint256 constant HALVE_INTERVAL = 880000;   
    uint256 constant HALVE_RATE = 90;           
    mapping(address => bool) public minersAddress;
    address public fineAcceptAddress;
    mapping(address => bool) public whiteAdmins;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public fromWhitelist;
    mapping(address => bool) public toWhitelist;
    mapping(address => Maturity) public userMaturity;
    struct Maturity {
        uint lastBlockHalve;
        uint blockNum;
        uint whiteBalance;
    }
    constructor(uint _startBlock) public {
        startBlock = _startBlock;
        lastBlockHalve = _startBlock;
    }
    function _setMinerAddress(address _minerAddress, bool flag) external onlyOwner{
        minersAddress[_minerAddress] = flag;
    }
    function _setFineAcceptAddress(address _fineAcceptAddress) external onlyOwner{
        fineAcceptAddress = _fineAcceptAddress;
    }
    function _setWhiteAdmin(address _whiteAdmin, bool flag) external onlyOwner{
        whiteAdmins[_whiteAdmin] = flag;
    }
    function _setWhiteListAll(uint whiteType, address[] memory users, bool[] memory flags) external onlyOwner{
        require(users.length == flags.length);
        for(uint i = 0; i < users.length; i++){
           _setWhiteList(whiteType, users[i], flags[i]);
        }
    }
    function _setWhiteList(uint whiteType, address user, bool flag) public{
        require(whiteAdmins[address(msg.sender)] || address(msg.sender) == owner(), "WhiteList:auth");
        if(whiteType == 0){
            whitelist[user] = flag;
        }
        if(whiteType == 1){
            fromWhitelist[user] = flag;
        }
        if(whiteType == 2){
            toWhitelist[user] = flag;
        }
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        uint fine = 0;
        if(whitelist[recipient] || toWhitelist[recipient]){
            if(!whitelist[sender]){
                Maturity storage maturity = userMaturity[sender];
                maturity.whiteBalance = maturity.whiteBalance.add(amount);
            }
        }else{
            Maturity storage maturity = userMaturity[recipient];
            if(maturity.lastBlockHalve == 0){
                maturity.lastBlockHalve = block.number;
            }
            if(whitelist[sender] || fromWhitelist[sender]){
                if(!fromWhitelist[sender]){
                    if(maturity.whiteBalance >= amount){
                        maturity.whiteBalance = maturity.whiteBalance.sub(amount);
                    }else{
                        maturity.whiteBalance = 0;
                    }
                }
            }else{
                fine = getFine(sender, amount);
                uint virtualAmount = balanceOf(recipient).add(maturity.whiteBalance);
                (uint currentMaturityTo, ) = currentMaturity(recipient);
                uint latestMaturity = 0;
                if(virtualAmount.add(amount) > 0){
                   latestMaturity = virtualAmount.mul(currentMaturityTo).div(virtualAmount.add(amount));
                }
                uint newBlockNum = getBlockNumByMaturity(latestMaturity);
                maturity.blockNum = newBlockNum;
                maturity.lastBlockHalve = block.number;
            }
        }
        super._transfer(sender, recipient, amount.sub(fine));
        if(fine > 0){
            super._transfer(sender, fineAcceptAddress, fine);
        }
    }
    function currentMaturity(address user) public view returns (uint mturityValue, uint blockNeeded){
        Maturity memory maturity = userMaturity[user];
        uint short = block.number.sub(maturity.lastBlockHalve);
        if(maturity.lastBlockHalve == 0){
            short = 0;
        }
        uint x0 = maturity.blockNum.add(short);
        (mturityValue, blockNeeded) = getMaturity(x0);
    }
    function getMaturity(uint blockNum) internal view returns (uint maturity, uint blockNeeded) {
        if(blockNum < uint(403200)){
            blockNeeded = uint(403200).sub(blockNum);
        }
        blockNum = blockNum.mul(denominator);
        if(blockNum < uint(201600).mul(denominator)){
            maturity = blockNum.div(806400);
        }
        if(blockNum >= uint(201600).mul(denominator) && blockNum < uint(403200).mul(denominator)){
            maturity = blockNum.div(268800).sub(5e17);
        }
        if(blockNum >= uint(403200).mul(denominator)){
            maturity = 1e18;
        }
    }
   function getBlockNumByMaturity(uint maturity)internal view returns (uint blockNum){
       if(maturity < 0.25e18){
           return maturity.mul(806400).div(denominator);
       }
       if(maturity >= 0.25e18 && maturity < 1e18){
           return maturity.add(5e17).mul(268800).div(denominator);
       }
       if(maturity >= 1e18){
           return 403200;
       }
   }
   function getFine(address user, uint amount) public view returns (uint) {
        (uint currentMaturityFrom, ) = currentMaturity(user);
        return amount.mul(denominator.sub(currentMaturityFrom)).div(5).div(denominator);
   }
    function mint(address _to, uint256 _amount) public {
        require(minersAddress[msg.sender], "!mint:auth");
        uint256 newTotal = totalSupply().add(_amount);
        updateSoftLimit();
        require(newTotal <= softLimit(), "^softLimit");
        require(newTotal <= hardLimit, "^hardLimit");
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }
    function updateSoftLimit() internal {
        if(block.number > startBlock){
            uint256 n = block.number.sub(startBlock).div(HALVE_INTERVAL)
                    - lastBlockHalve.sub(startBlock).div(HALVE_INTERVAL);
            for (uint i = 0; i < n; i++) {
                lastSoftLimit = lastSoftLimit.add(_issuePerBlock.mul(HALVE_INTERVAL));
                _issuePerBlock = _issuePerBlock.mul(HALVE_RATE).div(100);
                lastBlockHalve = block.number;
            }
        }
    }
    function softLimit() public view returns (uint) {
        uint256 _lastSoftLimit = lastSoftLimit;
        uint256 _lastBlockHalve = lastBlockHalve;
        uint256 __issuePerBlock = _issuePerBlock;
        if(block.number > startBlock){
            uint256 n = block.number.sub(startBlock).div(HALVE_INTERVAL) - lastBlockHalve.sub(startBlock).div(HALVE_INTERVAL);
            for (uint i = 0; i < n; i++) {
                _lastSoftLimit = _lastSoftLimit.add(__issuePerBlock.mul(HALVE_INTERVAL));
                __issuePerBlock = __issuePerBlock.mul(HALVE_RATE).div(100);
                _lastBlockHalve = block.number;
            }
            uint256 blocks = block.number.sub(_lastBlockHalve).add(1);
            return _lastSoftLimit.add(__issuePerBlock.mul(blocks));
        }
        return 0;
    }
    function issuePerBlock() public view returns (uint) {
        uint retval = _issuePerBlock;
        if (block.number >= startBlock) {
            uint256 n = block.number.sub(startBlock).div(HALVE_INTERVAL) - lastBlockHalve.sub(startBlock).div(HALVE_INTERVAL);
            for (uint i = 0; i < n; i++) {
                retval = retval.mul(HALVE_RATE).div(100);
            }
            return retval;
        }
        return 0;
    }
    mapping (address => address) internal _delegates;
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;
    mapping (address => uint32) public numCheckpoints;
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
    mapping (address => uint) public nonces;
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "PARA::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "PARA::delegateBySig: invalid nonce");
        require(now <= expiry, "PARA::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "PARA::getPriorVotes: not yet determined");
        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }
        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; 
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }
    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); 
        _delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }
    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }
            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }
    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "PARA::_writeCheckpoint: block number exceeds 32 bits");
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }
    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}
pragma experimental ABIEncoderV2;
pragma solidity 0.6.12;
interface IParaTicket {
    function level() external pure returns (uint256);
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
    function setApprovalForAll(address to, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function setUsed(uint256 tokenId) external;
    function _used(uint256 tokenId) external view returns(bool);
}
interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}
contract MasterChef is ParaProxyAdminStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct UserInfo {
        uint256 amount; 
        uint256 rewardDebt; 
    }
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accT42PerShare;
        IParaTicket ticket;
        uint256 pooltype;
    }
    uint8[10] public farmPercent;
    ParaToken public t42;
    address public devaddr;
    address public treasury;
    address public feeDistributor;
    uint256 public claimFeeRate;
    uint256 public withdrawFeeRate;
    uint256 public bonusEndBlock;
    uint256 public constant BONUS_MULTIPLIER = 1;
    IMigratorChef public migrator;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint;
    uint256 public startBlock;
    address public WETH;
    IParaRouter02 public paraRouter;
    mapping(address => mapping(address => uint)) public userChange;
    mapping(address => mapping(address => uint[])) public ticket_stakes;
    mapping(address => mapping(uint256 => uint256)) public _totalClaimed;
    mapping(address => address) public _whitelist;
    mapping(uint => uint) public poolsTotalDeposit;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event WithdrawChange(
        address indexed user,
        address indexed token,
        uint256 change);
    modifier onlyOwner() {
        require(admin == msg.sender, "Ownable: caller is not the owner");
        _;
    }
    constructor() public {
        admin = msg.sender;
    }
    function initialize(
        ParaToken _t42,
        address _treasury,
        address _feeDistributor,
        address _devaddr,
        uint256 _bonusEndBlock,
        address _WETH,
        IParaRouter02 _paraRouter
    ) external onlyOwner {
        t42 = _t42;
        treasury = _treasury;
        feeDistributor = _feeDistributor;
        devaddr = _devaddr;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _t42.startBlock();
        WETH = _WETH;
        paraRouter = _paraRouter;
        claimFeeRate = 500;
        withdrawFeeRate = 130;
    }
    function _become(ParaProxy proxy) public {
        require(msg.sender == proxy.admin(), "only proxy admin can change brains");
        require(proxy._acceptImplementation() == 0, "change not authorized");
    }
    function setWhitelist(address _whtie, address accpeter) public onlyOwner {
        _whitelist[_whtie] = accpeter;
    }
    function setT42(ParaToken _t42) public onlyOwner {
        require(address(_t42) != address(0), "Should not set _t42 to 0x0");
        t42 = _t42;
    }
    function setTreasury(address _treasury) public onlyOwner {
        require(_treasury != address(0), "Should not set treasury to 0x0");
        require(_treasury != treasury, "Need a different treasury address");
        treasury = _treasury;
    }
    function setRouter(address _router) public onlyOwner {
        require(_router != address(0), "Should not set _router to 0x0");
        require(_router != address(paraRouter), "Need a different treasury address");
        paraRouter = IParaRouter02(_router);
    }
    function setFeeDistributor(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "Should not set fee distributor to 0x0");
        require(_newAddress != feeDistributor, "Need a different fee distributor address");
        feeDistributor = _newAddress;
    }
    function setFarmPercents(uint8[] memory percents) public onlyOwner {
        uint8 sum = 0;
        uint8 i = 0;
        for (i = 0; i < percents.length; i++) {
            sum += percents[i];
        }
        require(sum == 100, "Total percent should be 100%");
        for (i = 0; i < percents.length; i++) {
            farmPercent[i] = percents[i];
        }
    }
    function t42PerBlock(uint8 index) public view returns (uint) {
        return t42.issuePerBlock().mul(farmPercent[index]).div(100);
    }
    function setClaimFeeRate(uint256 newRate) public onlyOwner {
        require(newRate <= 2000, "Claim fee rate should not be greater than 20%");
        require(newRate != claimFeeRate, "Need a different value");
        claimFeeRate = newRate;
    }
    function setWithdrawFeeRate(uint256 newRate) public onlyOwner {
        require(newRate <= 500, "Withdraw fee rate should not be greater than 5%");
        require(newRate != withdrawFeeRate, "Need a different value");
        withdrawFeeRate = newRate;
    }
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
	function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public returns (bytes4) {
        return this.onERC721Received.selector;
    }
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint256 _pooltype,
        IParaTicket _ticket,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accT42PerShare: 0,
                pooltype: _pooltype,
                ticket: _ticket
            })
        );
    }
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = poolsTotalDeposit[_pid];
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        uint newLpAmountNew = newLpToken.balanceOf(address(this));
        require(bal <= newLpAmountNew, "migrate: bad");
        pool.lpToken = newLpToken;
    }
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }
    function pendingT42(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending, uint256 fee)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accT42PerShare = pool.accT42PerShare;
        uint256 lpSupply = poolsTotalDeposit[_pid];
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 t42Reward =
                multiplier.mul(t42PerBlock(1)).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accT42PerShare = accT42PerShare.add(
                t42Reward.mul(1e12).div(lpSupply)
            );
        }
        pending = user.amount.mul(accT42PerShare).div(1e12).sub(user.rewardDebt);
        fee = pending.mul(claimFeeRate).div(10000);
    }
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = poolsTotalDeposit[_pid];
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 t42Reward =
            multiplier.mul(t42PerBlock(1)).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        t42.mint(treasury, t42Reward.div(9));
        t42.mint(address(this), t42Reward);
        pool.accT42PerShare = pool.accT42PerShare.add(
            t42Reward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }
    function depositSingle(uint256 _pid, address _token, uint256 _amount, address[][2] memory paths, uint _minTokens) payable external{
        depositSingleInternal(msg.sender, msg.sender, _pid, _token, _amount, paths, _minTokens);
    }
    function depositSingleTo(address _user, uint256 _pid, address _token, uint256 _amount, address[][2] memory paths, uint _minTokens) payable external{
        require(_whitelist[msg.sender] != address(0), "only white");
        IFeeDistributor(feeDistributor).setReferalByChef(_user, _whitelist[msg.sender]);
        depositSingleInternal(msg.sender, _user, _pid, _token, _amount, paths, _minTokens);
    }
    function depositByAddLiquidity(uint256 _pid, address[2] memory _tokens, uint256[2] memory _amounts) external{
        require(_amounts[0] > 0 && _amounts[1] > 0, "!0");
        address[2] memory tokens;
        uint256[2] memory amounts;
        (tokens[0], amounts[0]) = _doTransferIn(msg.sender, _tokens[0], _amounts[0]);
        (tokens[1], amounts[1]) = _doTransferIn(msg.sender, _tokens[1], _amounts[1]);
        depositByAddLiquidityInternal(msg.sender, _pid, tokens,amounts);
    }
    function depositByAddLiquidityETH(uint256 _pid, address _token, uint256 _amount) external payable{
        require(msg.value > 0 && _amount > 0, "!0");
        address[2] memory _tokens;
        uint256[2] memory _amounts;
        (_tokens[0], _amounts[0]) = _doTransferIn(msg.sender, _token, _amount);
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(address(this), msg.value));
        _tokens[1] = WETH;
        _amounts[1] = msg.value;
        depositByAddLiquidityInternal(msg.sender, _pid, _tokens, _amounts);
    }
    function depositByAddLiquidityInternal(address _user, uint256 _pid, address[2] memory _tokens, uint256[2] memory _amounts) internal {
        PoolInfo memory pool = poolInfo[_pid];
        require(address(pool.ticket) == address(0), "T:E");
        uint liquidity = addLiquidityInternal(address(pool.lpToken), _user, _tokens, _amounts);
        _deposit(_pid, liquidity, _user);
    }
    function addLiquidityInternal(address _lpAddress, address _user, address[2] memory _tokens, uint256[2] memory _amounts) internal returns (uint){
        DepositVars memory vars;
        approveIfNeeded(_tokens[0], address(paraRouter), _amounts[0]);
        approveIfNeeded(_tokens[1], address(paraRouter), _amounts[1]);
        vars.oldBalance = IERC20(_lpAddress).balanceOf(address(this));
        (vars.amountA, vars.amountB, vars.liquidity) = paraRouter.addLiquidity(_tokens[0], _tokens[1], _amounts[0], _amounts[1], 1, 1, address(this), block.timestamp + 600);
        vars.newBalance = IERC20(_lpAddress).balanceOf(address(this));
        require(vars.newBalance > vars.oldBalance, "B:E");
        vars.liquidity = vars.newBalance.sub(vars.oldBalance);
        addChange(_user, _tokens[0], _amounts[0].sub(vars.amountA));
        addChange(_user, _tokens[1], _amounts[1].sub(vars.amountB));
        return vars.liquidity;
    }
    struct DepositVars{
        uint oldBalance;
        uint newBalance;
        uint amountA;
        uint amountB;
        uint liquidity;
    }
    function depositSingleInternal(address payer, address _user, uint256 _pid, address _token, uint256 _amount, address[][2] memory paths, uint _minTokens) internal {
        require(paths.length == 2,"deposit: PE");
        (_token, _amount) = _doTransferIn(payer, _token, _amount);
        require(_amount > 0, "deposit: zero");
        (address[2] memory tokens, uint[2] memory amounts) = depositSwapForTokens(_token, _amount, paths);
        PoolInfo memory pool = poolInfo[_pid];
        require(address(pool.ticket) == address(0), "T:E");
        uint liquidity = addLiquidityInternal(address(pool.lpToken), _user, tokens, amounts);
        require(liquidity >= _minTokens, "H:S");
        _deposit(_pid, liquidity, _user);
    }
    function depositSwapForTokens(address _token, uint256 _amount, address[][2] memory paths) internal returns(address[2] memory tokens, uint[2] memory amounts){
        for (uint256 i = 0; i < 2; i++) {
            if(paths[i].length == 0){
                tokens[i] = _token;
                amounts[i] = _amount.div(2);
            }else{
                require(paths[i][0] == _token,"invalid path");
                approveIfNeeded(_token, address(paraRouter), _amount);
                (tokens[i], amounts[i]) = swapTokensIn(_amount.div(2), paths[i]);
            }
        }
    }
    function addChange(address user, address _token, uint change) internal returns(uint){
        if(change > 0){
            uint changeOld = userChange[user][_token];
            userChange[user][_token] = changeOld.add(change);
        }
    }
    function swapTokensIn(uint amountIn, address[] memory path) internal returns(address tokenOut, uint amountOut){
        uint[] memory amounts = paraRouter.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp + 600);
        tokenOut = path[path.length - 1];
        amountOut = amounts[amounts.length - 1];
    }
    function _claim(uint256 pooltype, uint pending) internal {
        uint256 fee = pending.mul(claimFeeRate).div(10000);
        safeT42Transfer(msg.sender, pending.sub(fee));
        _totalClaimed[msg.sender][pooltype] += pending.sub(fee);
        t42.approve(feeDistributor, fee);
        IFeeDistributor(feeDistributor).incomeClaimFee(msg.sender, address(t42), fee);
    }
    function totalClaimed(address _user, uint256 pooltype, uint index) public view returns (uint256) {
        if (pooltype > 0)
            return _totalClaimed[_user][pooltype];
            uint sum = 0;
            for(uint i = 0; i <= index; i++){
                sum += _totalClaimed[_user][i];
            }
        return sum;
    }
    function deposit_all_tickets(IParaTicket ticket) public {
        uint256[] memory idlist = ticket.tokensOfOwner(msg.sender);
        if (idlist.length > 0) {
            for (uint i = 0; i < idlist.length; i++) {
                uint tokenId = idlist[i];
                ticket.safeTransferFrom(msg.sender, address(this), tokenId);
                if(!ticket._used(tokenId)){
                    ticket.setUsed(tokenId);
                }
                ticket_stakes[msg.sender][address(ticket)].push(tokenId);
            }
        }
    }
    function ticket_staked_count(address who, address ticket) public view returns (uint) {
        return ticket_stakes[who][ticket].length;
    }
    function ticket_staked_array(address who, address ticket) public view returns (uint[] memory) {
        return ticket_stakes[who][ticket];
    }
    function check_vip_limit(uint ticket_level, uint ticket_count, uint256 amount) public view returns (uint allowed, uint overflow){
        uint256 limit;
        if (ticket_level == 0) limit = 1000 * 1e18;
        else if (ticket_level == 1) limit = 5000 * 1e18;
        else if (ticket_level == 2) limit = 10000 * 1e18;
        else if (ticket_level == 3) limit = 25000 * 1e18;
        else if (ticket_level == 4) limit = 100000 * 1e18;
        uint limitAll = ticket_count.mul(limit);
        if(amount <= limitAll){
            allowed = limitAll.sub(amount);
        }else{
            overflow = amount.sub(limitAll);
        }
    }
    function deposit(uint256 _pid, uint256 _amount) external {
        depositInternal(_pid, _amount, msg.sender, msg.sender);
    }
    function depositTo(uint256 _pid, uint256 _amount, address _user) external {
        require(_whitelist[msg.sender] != address(0), "only white");
        IFeeDistributor(feeDistributor).setReferalByChef(_user, _whitelist[msg.sender]);
        depositInternal(_pid, _amount, _user, msg.sender);
    }
    function depositInternal(uint256 _pid, uint256 _amount, address _user, address payer) internal {
        PoolInfo storage pool = poolInfo[_pid];
        pool.lpToken.safeTransferFrom(
            address(payer),
            address(this),
            _amount
        );
        if (address(pool.ticket) != address(0)) {
            UserInfo storage user = userInfo[_pid][_user];
            uint256 new_amount = user.amount.add(_amount);
            uint256 user_ticket_count = pool.ticket.tokensOfOwner(_user).length;
            uint256 staked_ticket_count = ticket_staked_count(_user, address(pool.ticket));
            uint256 ticket_level = pool.ticket.level();
            (, uint overflow) = check_vip_limit(ticket_level, user_ticket_count + staked_ticket_count, new_amount);
            require(overflow == 0, "Exceeding the ticket limit");
            deposit_all_tickets(pool.ticket);
        }
        _deposit(_pid, _amount, _user);
    }
    function _deposit(uint256 _pid, uint256 _amount, address _user) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        poolsTotalDeposit[_pid] = poolsTotalDeposit[_pid].add(_amount);
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accT42PerShare).div(1e12).sub(
                    user.rewardDebt
                );
            _claim(pool.pooltype, pending);
        }
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accT42PerShare).div(1e12);
        emit Deposit(_user, _pid, _amount);
    }
    function withdraw_tickets(uint256 _pid, uint256 tokenId) public {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][msg.sender];
        uint256[] storage idlist = ticket_stakes[msg.sender][address(pool.ticket)];
        for (uint i; i< idlist.length; i++) {
            if (idlist[i] == tokenId) {
                (, uint overflow) = check_vip_limit(pool.ticket.level(), idlist.length - 1, user.amount);
                require(overflow == 0, "Please withdraw usdt in advance");
                pool.ticket.safeTransferFrom(address(this), msg.sender, tokenId);
                idlist[i] = idlist[idlist.length - 1];
                idlist.pop();
                return;
            }
        }
        require(false, "You never staked this ticket before");
    }
    function withdraw(uint256 _pid, uint256 _amount) public {
        _withdrawInternal(_pid, _amount, msg.sender);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    function _withdrawInternal(uint256 _pid, uint256 _amount, address _operator) internal{
        (address lpToken,uint actual_amount) = _withdrawWithoutTransfer(_pid, _amount, _operator);
        IERC20(lpToken).safeTransfer(_operator, actual_amount);
    }
    function _withdrawWithoutTransfer(uint256 _pid, uint256 _amount, address _operator) internal returns (address lpToken, uint actual_amount){
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_operator];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accT42PerShare).div(1e12).sub(
                user.rewardDebt
            );
        _claim(pool.pooltype, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accT42PerShare).div(1e12);
        poolsTotalDeposit[_pid] = poolsTotalDeposit[_pid].sub(_amount);
        lpToken = address(pool.lpToken);
        uint fee = _amount.mul(withdrawFeeRate).div(10000);
        IERC20(lpToken).approve(feeDistributor, fee);
        IFeeDistributor(feeDistributor).incomeWithdrawFee(_operator, lpToken, fee, _amount);
        actual_amount = _amount.sub(fee);
    }
    function withdrawAndRemoveLiquidity(uint256 _pid, uint256 _amount, bool isBNB) external{
        (address lpToken, uint actual_amount) = _withdrawWithoutTransfer(_pid, _amount, msg.sender);
        approveIfNeeded(lpToken, address(paraRouter), actual_amount);
        address token0 = IParaPair(lpToken).token0();
        address token1 = IParaPair(lpToken).token1();
        if(isBNB){
            require(token0 == WETH || token1 == WETH, "!BNB");
            address token = token1;
            if(token1 == WETH){
                token = token0;
            }
            paraRouter.removeLiquidityETH(token, actual_amount, 1, 1, msg.sender, block.timestamp.add(600));
        }else{
             paraRouter.removeLiquidity(
            token0, token1, actual_amount, 1, 1, msg.sender, block.timestamp.add(600));
        }
    }
    function withdrawSingle(address tokenOut, uint256 _pid, uint256 _amount, address[][2] memory paths) external{
        require(paths[0].length >= 2 && paths[1].length >= 2, "PE:2");
        require(paths[0][paths[0].length - 1] == tokenOut,"invalid path_");
        require(paths[1][paths[1].length - 1] == tokenOut,"invalid path_");
        (address lpToken, uint actual_amount) = _withdrawWithoutTransfer(_pid, _amount, msg.sender);
        address[2] memory tokens;
        uint[2] memory amounts;
        tokens[0] = IParaPair(lpToken).token0();
        tokens[1] = IParaPair(lpToken).token1();
        approveIfNeeded(lpToken, address(paraRouter), actual_amount);
        (amounts[0], amounts[1]) = paraRouter.removeLiquidity(
            tokens[0], tokens[1], actual_amount, 0, 0, address(this), block.timestamp.add(600));
        for (uint i = 0; i < 2; i++){
            address[] memory path = paths[i];
            require(path[0] == tokens[0] || path[0] == tokens[1], "invalid path_0");
            if(path[0] == tokens[0]){
                swapTokensOut(amounts[0], tokenOut, path);
            }else{
                swapTokensOut(amounts[1], tokenOut, path);
            }
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }
    function approveIfNeeded(address _token, address spender, uint _amount) private{
        if (IERC20(_token).allowance(address(this), spender) < _amount) {
             IERC20(_token).approve(spender, _amount);
        }
    }
    function swapTokensOut(uint amountIn, address tokenOut, address[] memory path) internal {
        if(path[0] == path[1]){
            _doTransferOut(tokenOut, amountIn);
            return;
        }
        approveIfNeeded(path[0], address(paraRouter), amountIn);
        if(tokenOut == address(0)){
            paraRouter.swapExactTokensForETH(amountIn, 0, path, msg.sender, block.timestamp + 600);
        }else{
            paraRouter.swapExactTokensForTokens(amountIn, 0, path, msg.sender, block.timestamp + 600);
        }
    }
    function _doTransferOut(address _token, uint amount) private{
        if(_token == address(0)){
            IWETH(WETH).withdraw(amount);
            TransferHelper.safeTransferETH(msg.sender, amount);
        }else{
            IERC20(_token).safeTransfer(msg.sender, amount);
        }
    }
    function _doTransferIn(address payer, address _token, uint _amount) private returns(address, uint){
        if(_token == address(0)){
            _amount = msg.value;
            IWETH(WETH).deposit{value: _amount}();
            _token = WETH;
        }else{
            IERC20(_token).safeTransferFrom(address(payer), address(this), _amount);
        }
        return (_token, _amount);
    }
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint saved_amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        uint fee = saved_amount.mul(withdrawFeeRate).div(10000);
        pool.lpToken.safeTransfer(address(msg.sender), saved_amount.sub(fee));
        pool.lpToken.approve(feeDistributor, fee);
        IFeeDistributor(feeDistributor).incomeWithdrawFee(msg.sender, address(pool.lpToken), fee, saved_amount);
        emit EmergencyWithdraw(msg.sender, _pid, saved_amount);
    }
    function withdrawChange(address[] memory tokens) external{
        for(uint256 i = 0; i < tokens.length; i++){
            uint change = userChange[msg.sender][tokens[i]];
            userChange[msg.sender][tokens[i]] = 0;
            IERC20(tokens[i]).safeTransfer(address(msg.sender), change);
            emit WithdrawChange(msg.sender, tokens[i], change);
        }
    }
    function safeT42Transfer(address _to, uint256 _amount) internal {
        uint256 t42Bal = t42.balanceOf(address(this));
        if (_amount > t42Bal) {
            t42.transfer(_to, t42Bal);
        } else {
            t42.transfer(_to, _amount);
        }
    }
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}