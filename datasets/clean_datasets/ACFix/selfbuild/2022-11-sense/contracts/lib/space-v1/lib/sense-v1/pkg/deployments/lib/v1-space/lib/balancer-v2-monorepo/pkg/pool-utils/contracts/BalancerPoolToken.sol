pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20Permit.sol";
contract BalancerPoolToken is ERC20, ERC20Permit {
    constructor(string memory tokenName, string memory tokenSymbol)
        ERC20(tokenName, tokenSymbol)
        ERC20Permit(tokenName)
    {
    }
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = allowance(sender, msg.sender);
        _require(msg.sender == sender || currentAllowance >= amount, Errors.ERC20_TRANSFER_EXCEEDS_ALLOWANCE);
        _transfer(sender, recipient, amount);
        if (msg.sender != sender && currentAllowance != uint256(-1)) {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        return true;
    }
    function decreaseAllowance(address spender, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(msg.sender, spender);
        if (amount >= currentAllowance) {
            _approve(msg.sender, spender, 0);
        } else {
            _approve(msg.sender, spender, currentAllowance - amount);
        }
        return true;
    }
    function _mintPoolTokens(address recipient, uint256 amount) internal {
        _mint(recipient, amount);
    }
    function _burnPoolTokens(address sender, uint256 amount) internal {
        _burn(sender, amount);
    }
}