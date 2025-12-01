pragma solidity >=0.8.0;
import {Clone} from "clones/Clone.sol";
abstract contract CloneERC20 is Clone {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function name() external pure returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0)));
    }
    function symbol() external pure returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0x20)));
    }
    function decimals() external pure returns (uint8) {
        return _getArgUint8(0x40);
    }
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; 
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }
    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }
    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
    function _getImmutableVariablesOffset() internal pure returns (uint256 offset) {
        assembly {
            offset := sub(calldatasize(), add(shr(240, calldataload(sub(calldatasize(), 2))), 2))
        }
    }
}