pragma solidity ^0.7.0;
import "./ERC20.sol";
abstract contract ERC20Burnable is ERC20 {
    using SafeMath for uint256;
    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
    }
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, msg.sender).sub(amount, Errors.ERC20_BURN_EXCEEDS_ALLOWANCE);
        _approve(account, msg.sender, decreasedAllowance);
        _burn(account, amount);
    }
}