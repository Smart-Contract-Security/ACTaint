pragma solidity ^0.6.12;
import "../library/BEP20Upgradeable.sol";
contract QBridgeToken is BEP20Upgradeable {
    mapping(address => bool) private _minters;
    modifier onlyMinter() {
        require(isMinter(msg.sender), "QBridgeToken: caller is not the minter");
        _;
    }
    function initialize(string memory name, string memory symbol, uint8 decimals) external initializer {
        __BEP20__init(name, symbol, decimals);
    }
    function setMinter(address minter, bool canMint) external onlyOwner {
        _minters[minter] = canMint;
    }
    function mint(address _to, uint _amount) public onlyMinter {
        _mint(_to, _amount);
    }
    function burnFrom(address account, uint amount) public onlyMinter {
        uint decreasedAllowance = allowance(account, msg.sender).sub(amount, "BEP20: burn amount exceeds allowance");
        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
    function isMinter(address account) public view returns (bool) {
        return _minters[account];
    }
}