pragma solidity ^0.8.0;
import "../../token/ERC20/ERC20.sol";
abstract contract ERC20ForceApproveMock is ERC20 {
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        require(amount == 0 || allowance(msg.sender, spender) == 0, "USDT approval failure");
        return super.approve(spender, amount);
    }
}