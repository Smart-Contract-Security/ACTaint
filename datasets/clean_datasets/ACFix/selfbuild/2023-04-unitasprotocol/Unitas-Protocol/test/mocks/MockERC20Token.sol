pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract MockERC20Token is ERC20, Ownable {
    uint8 internal _decimals;
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals  = decimals_;
    }
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}