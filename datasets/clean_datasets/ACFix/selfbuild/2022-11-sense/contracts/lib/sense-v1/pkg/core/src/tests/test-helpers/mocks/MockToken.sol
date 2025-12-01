pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
contract MockToken is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimal
    ) ERC20(_name, _symbol, _decimal) {}
    function mint(address account, uint256 amount) external virtual {
        _mint(account, amount);
    }
    function burn(address account, uint256 amount) external virtual {
        _burn(account, amount);
    }
}
contract AuthdMockToken is ERC20, Trust {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimal
    ) ERC20(_name, _symbol, _decimal) Trust(msg.sender) {}
    function mint(address account, uint256 amount) external virtual requiresTrust {
        _mint(account, amount);
    }
    function burn(address account, uint256 amount) external virtual requiresTrust {
        _burn(account, amount);
    }
}
abstract contract NonERC20 {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
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
}
contract MockNonERC20Token is NonERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimal
    ) NonERC20(_name, _symbol, _decimal) {}
    function mint(address account, uint256 amount) external virtual {
        _mint(account, amount);
    }
    function burn(address account, uint256 amount) external virtual {
        _burn(account, amount);
    }
    function approve(address _spender, uint256 _value) public onlyPayloadSize(2 * 32) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }
    modifier onlyPayloadSize(uint256 size) {
        require(!(msg.data.length < size + 4));
        _;
    }
}