pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
contract Token is ERC20, Trust {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _trusted
    ) ERC20(_name, _symbol, _decimals) Trust(_trusted) {}
    function mint(address usr, uint256 amount) public requiresTrust {
        _mint(usr, amount);
    }
    function burn(address usr, uint256 amount) public requiresTrust {
        _burn(usr, amount);
    }
}