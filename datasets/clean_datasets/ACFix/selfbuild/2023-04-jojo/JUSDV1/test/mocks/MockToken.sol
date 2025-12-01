pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockToken is ERC20 {
    constructor(uint256 a) ERC20("Mock Token", "MK") {
        _mint(msg.sender, a);
    }
}