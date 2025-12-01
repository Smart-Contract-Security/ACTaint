pragma solidity ^0.5.0;
import "../../GSN/Context.sol";
import "./ERC20.sol";
contract ERC20Burnable is Context, ERC20 {
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
    function burnFrom(address account, uint256 amount) public {
        _burnFrom(account, amount);
    }
}