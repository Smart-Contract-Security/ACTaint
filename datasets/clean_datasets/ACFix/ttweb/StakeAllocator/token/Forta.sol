pragma solidity ^0.8.9;
import "./FortaCommon.sol";
contract Forta is FortaCommon {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant SUPPLY = 1000000000e18;
    error MintingMoreThanSupply();
    function initialize(address admin) public initializer {
        __FortaCommon_init(admin);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    }
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if (amount + totalSupply() > SUPPLY) revert MintingMoreThanSupply();
        _mint(to, amount);
    }
    function version() external pure virtual override returns(string memory) {
        return "0.2.0";
    }
    uint256[50] private __gap; 
}