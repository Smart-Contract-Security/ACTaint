pragma solidity 0.8.15;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {CloneERC20} from "./lib/CloneERC20.sol";
contract ERC20BondToken is CloneERC20 {
    error BondToken_OnlyTeller();
    function underlying() external pure returns (ERC20 _underlying) {
        return ERC20(_getArgAddress(0x41));
    }
    function expiry() external pure returns (uint48 _expiry) {
        return uint48(_getArgUint256(0x55));
    }
    function teller() internal pure returns (address _teller) {
        return _getArgAddress(0x75);
    }
    function mint(address to, uint256 amount) external {
        if (msg.sender != teller()) revert BondToken_OnlyTeller();
        _mint(to, amount);
    }
    function burn(address from, uint256 amount) external {
        if (msg.sender != teller()) revert BondToken_OnlyTeller();
        _burn(from, amount);
    }
}