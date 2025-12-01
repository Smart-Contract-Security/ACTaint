pragma solidity ^0.8.0;
import "../ERC777.sol";
contract ERC777PresetFixedSupply is ERC777 {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory defaultOperators,
        uint256 initialSupply,
        address owner
    ) ERC777(name, symbol, defaultOperators) {
        _mint(owner, initialSupply, "", "");
    }
}