pragma solidity ^0.7.0;
import "../BalancerPoolToken.sol";
contract MockBalancerPoolToken is BalancerPoolToken {
    constructor(string memory name, string memory symbol) BalancerPoolToken(name, symbol) {}
    function mint(address recipient, uint256 amount) external {
        _mintPoolTokens(recipient, amount);
    }
    function burn(address sender, uint256 amount) external {
        _burnPoolTokens(sender, amount);
    }
}