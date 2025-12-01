pragma solidity ^0.8.0;
import "../ERC777Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
contract ERC777PresetFixedSupplyUpgradeable is Initializable, ERC777Upgradeable {
    function initialize(
        string memory name,
        string memory symbol,
        address[] memory defaultOperators,
        uint256 initialSupply,
        address owner
    ) public virtual initializer {
        __ERC777PresetFixedSupply_init(name, symbol, defaultOperators, initialSupply, owner);
    }
    function __ERC777PresetFixedSupply_init(
        string memory name,
        string memory symbol,
        address[] memory defaultOperators,
        uint256 initialSupply,
        address owner
    ) internal onlyInitializing {
        __ERC777_init_unchained(name, symbol, defaultOperators);
        __ERC777PresetFixedSupply_init_unchained(name, symbol, defaultOperators, initialSupply, owner);
    }
    function __ERC777PresetFixedSupply_init_unchained(
        string memory,
        string memory,
        address[] memory,
        uint256 initialSupply,
        address owner
    ) internal onlyInitializing {
        _mint(owner, initialSupply, "", "");
    }
    uint256[50] private __gap;
}