pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockERC20 is ERC20 {
    constructor(uint256 a) ERC20("Mock ERC20 Type1", "MERC1") {
        _mint(msg.sender, a);
    }
}