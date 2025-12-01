pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract JUSD is Context, ERC20, Ownable {
    uint8 _decimals_;
    constructor(uint8 _decimals) ERC20("JUSD Token", "JUSD") {
        _decimals_ = _decimals;
    }
    function decimals() public view override returns (uint8) {
        return _decimals_;
    }
    function mint(uint256 amount) external onlyOwner {
        _mint(_msgSender(), amount);
    }
    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }
}